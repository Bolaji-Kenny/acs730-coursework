output "vpc_id" {
  value = module.app.vpc_id
}

output "subnet_ids" {
  value = module.app.subnet_ids
}

output "security_group_id" {
  value = module.app.security_group_id
}

output "web_public_ip" {
  value = module.app.web_public_ip
}

output "web_url" {
  value = module.app.web_url
}

output "artifact_bucket" {
  value = module.app.artifact_bucket
}

output "alarm_name" {
  value = module.app.alarm_name
}

output "alarm_arn" {
  value = module.app.alarm_arn
}

output "ssm_parameter_arn" {
  value = module.app.ssm_parameter_arn
}

output "ssm_parameter_version" {
  value = module.app.ssm_parameter_version
}
