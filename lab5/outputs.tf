output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Map of subnet name to subnet ID."
  value       = { for name, s in aws_subnet.public : name => s.id }
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL of the web server."
  value       = "http://${aws_instance.web.public_ip}"
}

output "bucket_name" {
  description = "Artifacts bucket name, or null when create_bucket is false."
  value       = one(aws_s3_bucket.artifacts[*].bucket)
}

output "provider_target" {
  description = "Which target this run points at. Check this before apply."
  value       = var.use_localstack ? "LocalStack (${var.localstack_endpoint})" : "REAL AWS (${var.region})"
}
