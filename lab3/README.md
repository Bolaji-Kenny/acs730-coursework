# Lab 3

## Credentials

A real AWS account would use OIDC: GitHub's token issuer is registered as an
identity provider, and an IAM role trusts it, scoped to this repository.
Each run GitHub mints a short-lived signed token that the runner trades with
STS, so nothing is stored long-term and there is no secret to leak or rotate.

This course cannot build that in AWS Academy because the lab role denies
iam:CreateOpenIDConnectProvider and iam:CreateRole, so instead it uses
session-scoped credentials from Vocareum, pushed into GitHub Actions secrets
by refresh-gha-creds.sh. The protection here is not secrecy but time: these
credentials expire when the lab session ends, which limits the damage if they
leak — they go stale within hours regardless.


## Operations

- ExpiredToken on a deploy: your lab session ended. Start a new one, re-run
  refresh-gha-creds.sh, re-run the job. Nothing in the repository changes.
- "Input required and not supplied: aws-region": the AWS_REGION variable does
  not exist — not a credential problem. Run the refresh script, or
  gh variable set AWS_REGION --body us-east-1.
- Terraform version used: 1.10.3

## Experiments




  
### Experiment 2: Remove the backend

Prediction: commenting out the S3 backend block and running
`terraform init -migrate-state` would copy my existing state into a local
`terraform.tfstate` file, since Terraform always preserves known resources
when switching backends.

Result: no local state file was created at all — `terraform show` printed
"No state." This makes sense in hindsight: I had already run
`terraform destroy` in Part 8, so the remote S3 state held zero resources.
There was nothing to migrate, so Terraform had nothing to write locally.
Had I run this experiment *before* destroying, a local terraform.tfstate
file would have appeared holding the one aws_ssm_parameter resource.

