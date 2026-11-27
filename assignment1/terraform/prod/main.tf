terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Same bucket as Lab 3, one state key per environment. The key is the ONLY
  # backend line that differs between dev/, staging/ and prod/.
  backend "s3" {
    bucket       = "acs730-tfstate-224364172046"
    key          = "assignment1/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Course = "ACS730"
      Lab    = "assignment1"
    }
  }
}

module "app" {
  source = "../modules/webapp"

  environment = "prod"
  vpc_cidr    = "10.30.0.0/16"
  public_subnets = {
    a = { cidr_block = "10.30.1.0/24", az_index = 0 }
    b = { cidr_block = "10.30.2.0/24", az_index = 1 }
  }
  instance_type              = "t3.small"
  create_artifact_bucket     = false
  db_password_parameter_name = "/acs730/assignment1/prod/db_password"
  alarm_cpu_threshold        = 70
  alarm_evaluation_periods   = 2
  tags = {
    Owner = "azeez"
  }
}
