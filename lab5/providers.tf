# One configuration, two targets. var.use_localstack decides which one.
#
#   use_localstack = false  -> real AWS, credentials from the environment
#   use_localstack = true   -> LocalStack on var.localstack_endpoint, dummy credentials
provider "aws" {
  region = var.region

  # Dummy credentials only when talking to LocalStack. null means
  # "use the normal credential chain" for real AWS.
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  # LocalStack has no real IAM/STS/metadata service, so skip those checks.
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # S3 on LocalStack needs path-style addressing (bucket.localhost does not resolve).
  s3_use_path_style = var.use_localstack

  endpoints {
    ec2 = var.use_localstack ? var.localstack_endpoint : null
    s3  = var.use_localstack ? var.localstack_endpoint : null
    sts = var.use_localstack ? var.localstack_endpoint : null
  }

  default_tags {
    tags = local.common_tags
  }
}
