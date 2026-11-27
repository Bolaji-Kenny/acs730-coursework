data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# AMI ids are regional and change when Amazon publishes a build, so look it up.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Task 6: the application secret is READ here, never created here.
# The parameter is created once, by hand, with aws ssm put-parameter
# (see REPORT.md). Creating and reading the same name in one graph would be
# circular and would fail on a fresh environment.
data "aws_ssm_parameter" "db_password" {
  name            = var.db_password_parameter_name
  with_decryption = true
}

locals {
  name = "${var.name_prefix}-${var.environment}"

  common_tags = merge(
    {
      Project     = "acs730-assignment1"
      Environment = var.environment
      Managed     = "terraform"
    },
    var.tags,
  )

  public_subnets = {
    for key, cfg in var.public_subnets : key => {
      cidr_block        = cfg.cidr_block
      availability_zone = data.aws_availability_zones.available.names[cfg.az_index]
    }
  }

  # keys() on a map returns sorted order, so this is stable across runs.
  first_subnet_key = keys(local.public_subnets)[0]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, { Name = "${local.name}-public-${each.key}" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Web ingress for ${local.name}. No SSH."
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    description = "All outbound (package installs, SSM agent over 443)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-web-sg" })
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[local.first_subnet_key].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = "LabInstanceProfile"

  metadata_options {
    http_tokens = "required"
  }

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y install nginx
    echo "<h1>ACS730 Assignment 1 - ${var.environment}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  # The route table association is not implied by any reference above. Without
  # this, user_data can run before the default route exists and dnf hangs.
  depends_on = [aws_route_table_association.public]

  tags = merge(local.common_tags, { Name = "${local.name}-web" })
}

# The optional bucket: count, not for_each (a yes/no about one resource).
resource "aws_s3_bucket" "artifacts" {
  count = var.create_artifact_bucket ? 1 : 0

  bucket        = "${local.name}-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "${local.name}-artifacts" })
}

# Task 7: one alarm on a real metric. CPUUtilization reports even on an idle
# instance, so after its evaluation periods the alarm reads OK instead of
# sitting in INSUFFICIENT_DATA.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-high"
  alarm_description   = "Average CPU on the ${var.environment} web instance is at or above ${var.alarm_cpu_threshold}%."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = local.common_tags
}
