variable "use_localstack" {
  description = "When true, point the AWS provider at LocalStack instead of real AWS."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "URL of the LocalStack edge endpoint (used only when use_localstack is true)."
  type        = string
  default     = "http://localhost:4566"
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must look like us-east-1."
  }
}

variable "project" {
  description = "Short project name, used as a prefix in resource names and tags."
  type        = string
  default     = "acs730-lab5"
}

variable "env" {
  description = "Environment name, used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.50.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, for example 10.50.0.0/16."
  }
}

variable "public_subnets" {
  description = "Public subnets to create. Map key = subnet name; az_index picks an availability zone."
  type = map(object({
    cidr     = string
    az_index = number
  }))
  default = {
    public-a = { cidr = "10.50.1.0/24", az_index = 0 }
    public-b = { cidr = "10.50.2.0/24", az_index = 1 }
  }
}

variable "web_subnet_key" {
  description = "Key in public_subnets where the web server is placed."
  type        = string
  default     = "public-a"
}

variable "allowed_ingress_ports" {
  description = "TCP ports opened to the internet on the web security group."
  type        = list(number)
  default     = [22, 80]
}

variable "instance_type" {
  description = "EC2 instance type for the web server."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of t2.micro, t3.micro, t3.small."
  }
}

variable "ami_name_filter" {
  description = "Name pattern used by the AMI data source."
  type        = string
  default     = "al2023-ami-2023*-x86_64"
}

variable "ami_owners" {
  description = "AMI owners for the AMI data source."
  type        = list(string)
  default     = ["amazon"]
}

variable "create_bucket" {
  description = "Create the optional artifacts S3 bucket (count-gated)."
  type        = bool
  default     = false
}
