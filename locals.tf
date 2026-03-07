locals {
  name_prefix = "${var.project_name}-${var.environment}"

  enable_https = var.certificate_arn != null

  target_group_map = { for idx, tg in var.target_groups : tg.name => idx }

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "terraform-aws-alb"
  })
}
