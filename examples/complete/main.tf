provider "aws" {
  region = "us-east-1"
}

resource "aws_acm_certificate" "this" {
  domain_name               = "app.example.com"
  subject_alternative_names = ["api.example.com"]
  validation_method         = "DNS"
}

module "alb" {
  source = "../../"

  project_name = "my-app"
  environment  = "prod"
  vpc_id       = "vpc-0123456789abcdef0"
  subnet_ids   = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]

  internal                   = false
  idle_timeout               = 120
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  certificate_arn             = aws_acm_certificate.this.arn
  additional_certificate_arns = []
  ssl_policy                  = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  target_groups = [
    {
      name        = "web"
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        path     = "/health"
        matcher  = "200-299"
        interval = 15
      }
    },
    {
      name        = "api"
      port        = 3000
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        path    = "/api/health"
        matcher = "200"
      }
      stickiness = {
        enabled         = true
        type            = "lb_cookie"
        cookie_duration = 3600
      }
    }
  ]

  listener_rules = [
    {
      priority         = 100
      target_group_key = "api"
      conditions = [
        {
          type   = "path_pattern"
          values = ["/api/*"]
        }
      ]
    },
    {
      priority         = 200
      target_group_key = "api"
      conditions = [
        {
          type   = "host_header"
          values = ["api.example.com"]
        }
      ]
    }
  ]

  enable_access_logs        = true
  access_logs_bucket_prefix = "prod-alb-logs"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Team       = "platform"
    CostCenter = "engineering"
  }
}

output "alb_dns" {
  value = module.alb.alb_dns_name
}

output "target_groups" {
  value = module.alb.target_group_arns
}
