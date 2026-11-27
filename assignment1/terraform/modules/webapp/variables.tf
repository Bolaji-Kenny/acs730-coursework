variable "environment" {
  description = "Environment name. Drives resource names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "name_prefix" {
  description = "Prefix for resource names. Identical in every environment, so a default, not an input."
  type        = string
  default     = "acs730-a1"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.name_prefix))
    error_message = "name_prefix: 3-24 lowercase letters, digits, hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the environment's VPC. Differs per environment so the three never overlap."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, for example 10.10.0.0/16."
  }
}

variable "public_subnets" {
  description = "Public subnets to create, keyed by a short stable name (the key becomes the resource address)."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))

  validation {
    condition     = length(var.public_subnets) >= 1
    error_message = "Define at least one public subnet."
  }
}

variable "ingress_rules" {
  description = "Ingress rules for the web security group, rendered by a dynamic block. No SSH: Session Manager is the way in."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { description = "HTTP from anywhere", port = 80, cidr_blocks = ["0.0.0.0/0"] },
  ]

  validation {
    condition     = alltrue([for r in var.ingress_rules : r.port != 22])
    error_message = "Port 22 is not allowed. Use Session Manager."
  }
}

variable "instance_type" {
  description = "Instance type for the web server. Differs per environment."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Stay small: t3.micro or t3.small. The term budget is $50 in total."
  }
}

variable "create_artifact_bucket" {
  description = "Create the optional artifact bucket. Gated with count, because the question is yes or no for one resource."
  type        = bool
  default     = false
}

variable "db_password_parameter_name" {
  description = "Name of an EXISTING SSM parameter holding the placeholder DB password. Created out of band with aws ssm put-parameter; this module only reads it."
  type        = string

  validation {
    condition     = startswith(var.db_password_parameter_name, "/")
    error_message = "SSM parameter names used here must start with a slash."
  }
}

variable "alarm_cpu_threshold" {
  description = "CPUUtilization percentage at or above which the alarm fires."
  type        = number
  default     = 80

  validation {
    condition     = var.alarm_cpu_threshold > 0 && var.alarm_cpu_threshold <= 100
    error_message = "alarm_cpu_threshold must be greater than 0 and at most 100."
  }
}

variable "alarm_period" {
  description = "Alarm period in seconds. Basic EC2 monitoring reports every 300 seconds."
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300], var.alarm_period)
    error_message = "alarm_period must be 60 or 300."
  }
}

variable "alarm_evaluation_periods" {
  description = "Consecutive periods evaluated before the alarm leaves INSUFFICIENT_DATA."
  type        = number
  default     = 2

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 6
    error_message = "alarm_evaluation_periods must be between 1 and 6."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
