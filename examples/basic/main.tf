provider "aws" {
  region = "us-east-1"
}

module "alb" {
  source = "../../"

  project_name = "my-app"
  environment  = "dev"
  vpc_id       = "vpc-0123456789abcdef0"
  subnet_ids   = ["subnet-aaa", "subnet-bbb"]

  target_groups = [
    {
      name        = "web"
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        path = "/health"
      }
    }
  ]

  tags = {
    Team = "platform"
  }
}

output "alb_dns" {
  value = module.alb.alb_dns_name
}
