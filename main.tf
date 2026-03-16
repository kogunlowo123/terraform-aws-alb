###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "this" {
  name        = "${var.name}-alb-sg"
  description = "Security group for ${var.name} ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTP inbound"
}

resource "aws_security_group_rule" "https_ingress" {
  count = var.certificate_arn != null ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.ingress_cidr_blocks
  security_group_id = aws_security_group.this.id
  description       = "Allow HTTPS inbound"
}

resource "aws_security_group_rule" "sg_ingress" {
  for_each = toset(var.ingress_security_group_ids)

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.this.id
  description              = "Allow traffic from security group ${each.value}"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound"
}

###############################################################################
# S3 Bucket for Access Logs
###############################################################################

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = "${var.name}-alb-access-logs"

  tags = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.access_logs[0].arn}/${var.access_logs_bucket_prefix}/*"
      }
    ]
  })
}

###############################################################################
# Application Load Balancer
###############################################################################

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.this.id]
  subnets            = var.subnet_ids

  idle_timeout                     = var.idle_timeout
  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  drop_invalid_header_fields       = var.drop_invalid_header_fields

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.access_logs[0].id
      prefix  = var.access_logs_bucket_prefix
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-alb"
  })
}

###############################################################################
# Target Groups
###############################################################################

resource "aws_lb_target_group" "this" {
  count = length(var.target_groups)

  name                 = "${var.name}-${var.target_groups[count.index].name}"
  port                 = var.target_groups[count.index].port
  protocol             = var.target_groups[count.index].protocol
  vpc_id               = var.vpc_id
  target_type          = var.target_groups[count.index].target_type
  deregistration_delay = var.target_groups[count.index].deregistration_delay

  health_check {
    enabled             = var.target_groups[count.index].health_check.enabled
    path                = var.target_groups[count.index].health_check.path
    port                = var.target_groups[count.index].health_check.port
    protocol            = var.target_groups[count.index].health_check.protocol
    healthy_threshold   = var.target_groups[count.index].health_check.healthy_threshold
    unhealthy_threshold = var.target_groups[count.index].health_check.unhealthy_threshold
    timeout             = var.target_groups[count.index].health_check.timeout
    interval            = var.target_groups[count.index].health_check.interval
    matcher             = var.target_groups[count.index].health_check.matcher
  }

  dynamic "stickiness" {
    for_each = var.target_groups[count.index].stickiness.enabled ? [1] : []
    content {
      type            = var.target_groups[count.index].stickiness.type
      cookie_duration = var.target_groups[count.index].stickiness.cookie_duration
      enabled         = true
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.target_groups[count.index].name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# Listeners
###############################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn != null ? null : (
      length(aws_lb_target_group.this) > 0 ? aws_lb_target_group.this[0].arn : null
    )
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = length(aws_lb_target_group.this) > 0 ? aws_lb_target_group.this[0].arn : null
  }

  tags = var.tags
}

###############################################################################
# Additional Certificates
###############################################################################

resource "aws_lb_listener_certificate" "this" {
  for_each = var.certificate_arn != null ? toset(var.additional_certificate_arns) : toset([])

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

###############################################################################
# Listener Rules
###############################################################################

resource "aws_lb_listener_rule" "this" {
  count = length(var.listener_rules)

  listener_arn = var.certificate_arn != null ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = var.listener_rules[count.index].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[index(var.target_groups[*].name, var.listener_rules[count.index].target_group_key)].arn
  }

  dynamic "condition" {
    for_each = var.listener_rules[count.index].conditions
    content {
      dynamic "host_header" {
        for_each = condition.value.type == "host_header" ? [1] : []
        content {
          values = condition.value.values
        }
      }

      dynamic "path_pattern" {
        for_each = condition.value.type == "path_pattern" ? [1] : []
        content {
          values = condition.value.values
        }
      }

      dynamic "http_header" {
        for_each = condition.value.type == "http_header" ? [1] : []
        content {
          http_header_name = condition.value.values[0]
          values           = slice(condition.value.values, 1, length(condition.value.values))
        }
      }
    }
  }

  tags = var.tags
}

###############################################################################
# WAF Association
###############################################################################

resource "aws_wafv2_web_acl_association" "this" {
  count = var.waf_arn != null ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_arn
}
