output "alb_id" {
  description = "The ID of the ALB"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The hosted zone ID of the ALB"
  value       = aws_lb.this.zone_id
}

output "security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "target_group_arns" {
  description = "List of target group ARNs"
  value       = aws_lb_target_group.this[*].arn
}

output "target_group_names" {
  description = "List of target group names"
  value       = aws_lb_target_group.this[*].name
}

output "access_logs_bucket_id" {
  description = "The ID of the access logs S3 bucket"
  value       = length(aws_s3_bucket.access_logs) > 0 ? aws_s3_bucket.access_logs[0].id : null
}
