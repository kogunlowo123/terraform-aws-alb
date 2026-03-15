terraform {
  required_version = ">= 1.7.0"
}

module "test" {
  source = "../"

  project_name = "test-alb"
  environment  = "test"
  vpc_id       = "vpc-0123456789abcdef0"
  subnet_ids   = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]

  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false
  enable_http2               = true
  drop_invalid_header_fields = true

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-ef56-gh78-ij90-klmnopqrstuv"

  target_groups = [
    {
      name        = "test-tg"
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        enabled             = true
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
    }
  ]

  listener_rules = [
    {
      priority         = 100
      target_group_key = "test-tg"
      conditions = [
        {
          type   = "path-pattern"
          values = ["/api/*"]
        }
      ]
    }
  ]

  enable_access_logs    = false
  ingress_cidr_blocks   = ["10.0.0.0/8"]

  tags = {
    Test = "true"
  }
}
