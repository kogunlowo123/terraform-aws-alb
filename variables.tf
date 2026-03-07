variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

variable "internal" {
  description = "Whether the ALB is internal or internet-facing"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout for the ALB in seconds"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALB"
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Drop invalid header fields"
  type        = bool
  default     = true
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listeners"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "certificate_arn" {
  description = "Default ACM certificate ARN for HTTPS listener"
  type        = string
  default     = null
}

variable "additional_certificate_arns" {
  description = "List of additional ACM certificate ARNs"
  type        = list(string)
  default     = []
}

variable "target_groups" {
  description = "List of target group configurations"
  type = list(object({
    name                 = string
    port                 = number
    protocol             = optional(string, "HTTP")
    target_type          = optional(string, "ip")
    deregistration_delay = optional(number, 300)
    health_check = optional(object({
      enabled             = optional(bool, true)
      path                = optional(string, "/health")
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
      timeout             = optional(number, 5)
      interval            = optional(number, 30)
      matcher             = optional(string, "200")
    }), {})
    stickiness = optional(object({
      enabled         = optional(bool, false)
      type            = optional(string, "lb_cookie")
      cookie_duration = optional(number, 86400)
    }), {})
  }))
  default = []
}

variable "listener_rules" {
  description = "List of listener rule configurations"
  type = list(object({
    priority         = number
    target_group_key = string
    conditions = list(object({
      type   = string
      values = list(string)
    }))
  }))
  default = []
}

variable "enable_access_logs" {
  description = "Enable access logging to S3"
  type        = bool
  default     = false
}

variable "access_logs_bucket_prefix" {
  description = "Prefix for access log files in S3"
  type        = string
  default     = "alb-logs"
}

variable "waf_arn" {
  description = "WAF Web ACL ARN to associate with the ALB"
  type        = string
  default     = null
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_security_group_ids" {
  description = "Security group IDs allowed to access the ALB"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
