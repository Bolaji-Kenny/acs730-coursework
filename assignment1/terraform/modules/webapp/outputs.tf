output "vpc_id" {
  description = "Id of the VPC this module created."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet ids, keyed like var.public_subnets."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "web_instance_id" {
  description = "ID of the web instance."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to curl once the instance has booted."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "artifact_bucket" {
  description = "Name of the optional bucket, or null when it was not created."
  value       = one(aws_s3_bucket.artifacts[*].bucket)
}

output "alarm_name" {
  description = "Name of the CPU alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "alarm_arn" {
  description = "ARN of the CPU alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

# Proof the data source resolved, without printing the secret itself.
output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter that was read."
  value       = data.aws_ssm_parameter.db_password.arn
}

output "ssm_parameter_version" {
  description = "Version of the SSM parameter that was read."
  value       = data.aws_ssm_parameter.db_password.version
}
