# Assignment 1: Multi-Environment Deployment Pipeline

Azeez Kehinde Bolaji, ACS730 Cloud Automation
Repository: https://github.com/Bolaji-Kenny/acs730-coursework

## Introduction

This assignment extends the Terraform infrastructure from Week 7 into a reusable, secure, multi-environment deployment. I refactored the network and web server into a single Terraform module and called it from separate dev, staging and prod directories. Each directory has its own state key in a shared S3 backend, so the environments cannot overwrite one another.

Deployment runs through GitHub Actions and GitHub Environments. Staging applies automatically when a change merges to main, and production waits for a manual reviewer and deploys only from main. The pipeline uses only the session-scoped AWS Academy credentials, which I moved from repository level to environment-scoped secrets, with no long-lived AWS keys anywhere. I also wrote the OIDC trust policy I would use in a real AWS account.

The application reads a placeholder database password from AWS Systems Manager Parameter Store, and a CloudWatch alarm monitors CPU in each environment. Working through a real deployment in the Learner Lab, I examined the practical benefits and limits of this approach and compared it with an AWS-native pipeline for an organization that runs only on AWS.

## 1. Reusable module and environment directories (Tasks 1 and 2)

The resources are the Week 7 (Lab 5) network, lifted into one module, `assignment1/terraform/modules/webapp/`: a VPC, public
subnets built with `for_each`, an internet gateway, a route table and associations, a security group from a `dynamic` block (HTTP
only, no port 22), a web instance with `user_data` and an explicit `depends_on`, and an optional artifact bucket gated with `count`. Two additions
for this assignment: one `data "aws_ssm_parameter"` (Task 6) and one CloudWatch alarm (Task 7). Everything is wired by attribute
reference and looked up with data sources (region, availability zones, AMI), with no AMI, VPC, subnet or security group id typed in.

| Input | Why it is an input (what differs between environments) |
|---|---|
| `environment` | names and tags; validated to `dev`, `staging` or `prod` |
| `vpc_cidr` | each environment gets its own non-overlapping range (10.10, 10.20, 10.30) |
| `public_subnets` | map of subnets per environment; the key is the stable resource address |
| `instance_type` | prod uses `t3.small`, the others `t3.micro`; validated to small sizes for the $50 budget |
| `create_artifact_bucket` | optional bucket behind a `count` gate; off in all three environments (see section 4) |
| `db_password_parameter_name` | each environment reads its own parameter |
| `alarm_cpu_threshold`, `alarm_period`, `alarm_evaluation_periods` | alarm sensitivity differs per environment |
| `ingress_rules`, `tags` | rules default to HTTP only (port 22 is rejected by a validation); extra tags per environment |

`name_prefix` has a default because it is the same everywhere. The module outputs `vpc_id`, `subnet_ids`, the web instance ID, `web_public_ip`,
`web_url`, `artifact_bucket`, the security group ID, the alarm name and ARN, and the ARN and version of the SSM parameter it read.

`dev/`, `staging/` and `prod/` each contain only a `main.tf` that calls `../modules/webapp` with its own values and
an `outputs.tf` that passes the module outputs through. Each has its own backend block. The bucket is the Lab 3 bucket and
the key is the only line that differs:

| Environment | State key |
|---|---|
| dev | `assignment1/dev/terraform.tfstate` |
| staging | `assignment1/staging/terraform.tfstate` |
| prod | `assignment1/prod/terraform.tfstate` |

`evidence/backend-state-keys.txt` lists the bucket and shows three distinct keys.

## 2. GitHub Environments (Task 3)

- `staging`: no reviewer, so a merge to `main` applies it automatically.
- `prod`: at least one required reviewer (me), and a deployment branch policy that allows only `main`.

The workflow `.github/workflows/assignment1-deploy.yml` runs `validate` (fmt and validate for all three
directories), then on a pull request `plan staging`, and on a push to `main` `deploy staging`, then `deploy prod`
(`needs: deploy-staging`). The prod job pauses on the environment's approval gate. A `concurrency` group stops two runs from
applying at once. The workflow is scoped with `paths: assignment1/**`; evidence, report and scripts are excluded so committing them never triggers a deploy.

Evidence: `environments.json` (the protection rules and branch policy as returned by the API).

## 3. Scoped credentials (Task 4)

The three AWS credential secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) are stored at
environment scope on `staging` and `prod`, and the repository-level copies were deleted.
`evidence/secrets-scope.txt` shows the repository list empty of those names and both environment lists containing all three.

From this assignment on, the per-session refresh is:

```
./scripts/refresh-gha-creds.sh Bolaji-Kenny/acs730-coursework staging prod
```

The old two-argument form still exits 0 but writes repository-level secrets that no job can read.

### OIDC trust policy I would deploy in a real AWS account (prod role)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Bolaji-Kenny/acs730-coursework:environment:prod"
        }
      }
    }
  ]
}
```

(`123456789012` stands in for the account ID.)

What each part prevents:

- **`Principal.Federated` (the GitHub OIDC provider) with `sts:AssumeRoleWithWebIdentity`.** Only a web-identity token signed by
  GitHub's OIDC provider can use this role. No IAM user, no static access key and no other identity provider can assume it,
  and there is no long-lived credential to leak.
- **`aud` equals `sts.amazonaws.com`.** The token must have been issued for AWS STS. A token that GitHub minted for some other
  service or audience cannot be replayed against this role.
- **`sub` equals `repo:Bolaji-Kenny/acs730-coursework:environment:prod`.** `sub` is the claim that says *which workflow context*
  the token came from. GitHub puts `environment:prod` in it only for a job that targets the `prod` environment, and a job only gets there
  after the environment's rules pass: the required reviewer approves and the branch policy confirms the run is from `main`. Pinning `sub` to that value
  therefore means the role can be assumed only by a prod deployment that a human approved, from `main`.
- **`StringEquals`, not `StringLike`.** There is no wildcard in the value, so no other repository, other environment or other branch can match it by accident.

**What the loose version would allow.** A repo-wide wildcard such as `repo:Bolaji-Kenny/acs730-coursework:*` matches every token
this repository can ever produce. Someone with push access to *any* branch could add a workflow on a feature branch that does not
declare `environment: prod` at all, so no reviewer and no branch policy applies. Its token would carry
`sub = repo:Bolaji-Kenny/acs730-coursework:ref:refs/heads/their-branch`, which matches the wildcard, and that workflow could assume the prod
role and change prod directly, skipping the approval gate. The same applies to a pull request token
(`...:pull_request`). With `sub` pinned to `environment:prod`, those tokens are rejected by AWS regardless of what the workflow file says,
so the approval gate cannot be bypassed by editing YAML. The control is enforced by AWS, not by the repository.

**Why it was not deployed.** The Learner Lab denies the IAM writes this needs (`iam:CreateOpenIDConnectProvider`,
`iam:CreateRole`), so this policy is examined in writing only. This course uses session-scoped Academy credentials instead, which
expire when the lab session ends, and they are stored at environment scope so that prod's credentials are released only to the gated job.

## 4. Real deployment (Task 5)

A merge to `main` applied `staging` automatically with no human step, then the `prod` job waited on the reviewer gate. I took
`prod-approval-pending.png` while it waited, approved, and took `prod-approval-approved.png`; the prod apply then completed.

**What went wrong, and the fix.** The first prod run created everything except the optional artifact bucket, then failed: after creating a bucket the AWS provider reads
its object-lock settings, and the Learner Lab service control policy explicitly denies `s3:GetBucketObjectLockConfiguration`. I removed the half-created bucket from state, destroyed
the prod resources, set `create_artifact_bucket = false` in prod (the `count` gate working as designed; the bucket was never a requirement), and ran the pipeline again. The second
prod run, after a fresh approval, created all 10 resources. The approval screenshots and `prod-apply.txt` come from that second run; `staging-apply.txt` is from the first run.

Evidence: `staging-apply.txt`, `prod-apply.txt`, `prod-approval-pending.png`, `prod-approval-approved.png`.

## 5. Secrets management with SSM Parameter Store (Task 6)

The placeholder database password is a `SecureString` parameter, one per environment
(`/acs730/assignment1/<env>/db_password`). It is created once, by hand, before any plan that reads it. This is the
documented pre-step (`assignment1/scripts/put-parameters.sh` runs it for the three environments):

```
aws ssm put-parameter --region us-east-1 \
  --name /acs730/assignment1/dev/db_password \
  --type SecureString \
  --value "placeholder-dev-not-a-real-password" \
  --overwrite
```

Terraform only reads it, through `data "aws_ssm_parameter" "db_password"` in the module. There is no `aws_ssm_parameter` resource anywhere,
because creating and reading the same parameter in one graph is circular and fails on a fresh environment, which is exactly what CI
plans. The value is never written in the repository or printed in an output; the module outputs only the parameter's ARN and version.

Evidence: `ssm-parameter.txt` (the grep for `aws_ssm_parameter`, the ARN and version Terraform read, and the parameter's name, type and version).

## 6. CloudWatch alarm (Task 7)

One alarm per environment, defined in the module: `AWS/EC2` `CPUUtilization`, statistic Average, period 300 s, 2 evaluation
periods, threshold 80% (70% in prod), on the web instance. CPU is used because it is reported even by an idle instance, so after
the evaluation periods the alarm reads `OK` rather than `INSUFFICIENT_DATA`.

Evidence: `cloudwatch-alarm.json` and `cloudwatch-alarm.png`, captured after several evaluation periods.

## 7. Recommendation (Task 8)

Although GitHub Actions successfully automated infrastructure deployment in this assignment, I would recommend an AWS-native pipeline using AWS CodePipeline and AWS CodeBuild for an organization fully committed to AWS with no multi-cloud plans. My recommendation is based on four main factors.

**1. Security and identity management**

During this assignment, the three temporary AWS credentials had to be refreshed for both staging and production whenever the Learner Lab session expired. In a real AWS account, OIDC federation would eliminate this manual process, and configuring the trust policy would be a one-time task. However, an AWS-native pipeline would use IAM service roles directly without relying on an external identity provider. This keeps the pipeline's deployment identity within AWS and allows permissions to be managed through the organization's existing IAM policies.

**2. Integration with AWS services**

Although Terraform can retrieve values from SSM Parameter Store and create CloudWatch alarms regardless of the pipeline used, an AWS-native pipeline provides more direct integration with AWS operational services. For example, EventBridge can trigger CodePipeline in response to AWS events, while CloudWatch can monitor pipeline activity and provide notifications when failures occur. This allows infrastructure deployment and operational monitoring to be managed within the same AWS ecosystem without requiring additional integration with an external CI/CD platform.

**3. Governance and accountability**

GitHub Actions provided effective deployment controls through environment-scoped secrets, branch restrictions, and manual production approval. However, GitHub reviewers are identified through GitHub accounts, whereas CodePipeline approvers act as IAM principals. AWS CloudTrail can record approval API calls against those principals, providing more direct accountability within AWS. With GitHub Actions, CloudTrail generally records AWS deployment activity against the assumed deployment role rather than the GitHub reviewer.

The service control policy that blocked the optional S3 bucket during my production deployment would also restrict a CodeBuild role. Therefore, switching pipelines would not eliminate permission restrictions. Instead, it would allow deployment identities and approval permissions to be governed within the same AWS security framework.

**4. Private network access**

As demonstrated in Lab 7, a standard GitHub-hosted runner cannot directly access resources inside a private VPC subnet without additional network connectivity. A self-hosted runner inside the VPC is one possible solution, but it introduces maintenance, patching, and security responsibilities. CodeBuild can be configured to operate within the VPC, allowing it to communicate with private resources without maintaining a dedicated runner. Regarding cost, standard GitHub-hosted runners are free for public repositories, whereas CodeBuild charges for build usage beyond applicable free allowances.

**Trade-offs and final decision**

Moving away from GitHub Actions would mean giving up the convenience of maintaining workflow definitions alongside application code, familiar pull request integration, and a relatively straightforward initial setup. CodePipeline can require more configuration during implementation.

However, for an AWS-only organization, the advantages of native identity management, centralized governance, operational integration, and private network access outweigh these disadvantages. Therefore, my final recommendation is AWS CodePipeline and AWS CodeBuild combined with Terraform.

## 8. Teardown (Task 9)

All three environments were destroyed with `assignment1/scripts/destroy-all.sh`, which writes
`evidence/destroy-complete.txt`, deletes the out-of-band SSM parameters, and ends with `cleanup-check.sh`, which found no Assignment 1 resources left. It still lists my workstation (kept) and two items from earlier work that are not part of this assignment: a security group and a stale practice state file.

## Evidence index

| File | Shows |
|---|---|
| `backend-state-keys.txt` | three distinct state keys in one bucket |
| `environments.json` | staging with no reviewer; prod with a reviewer and a `main`-only branch policy |
| `secrets-scope.txt` | no AWS secret at repository level; all three at both environments |
| `prod-approval-pending.png` | prod job waiting for approval |
| `prod-approval-approved.png` | immediately after approval |
| `staging-apply.txt` | automatic staging apply log |
| `prod-apply.txt` | approved prod apply log |
| `ssm-parameter.txt` | the data source read |
| `cloudwatch-alarm.json` / `.png` | alarm in a state other than `INSUFFICIENT_DATA` |
| `destroy-complete.txt` | destroy output and cleanup check |

## Conclusion

This assignment showed me that a working pipeline takes more than valid Terraform. State management, credential handling, deployment controls and the limits of the cloud account all decide whether a deployment succeeds.

The most surprising problem was the production deployment failing after most of it had succeeded. Terraform created the VPC, instance and alarm, but the optional artifact bucket failed because the Learner Lab service control policy denies a read the AWS provider makes right after creating a bucket. That left a half-built environment. I removed the bucket from state, destroyed what had been created, turned the optional bucket off, and redeployed with a fresh approval. I also avoided two traps the assignment warned about: a copied backend key that makes environments share one state file, and a refresh script that succeeds while writing secrets no job can read. Checking the three state keys and the secret scopes before deploying is why neither happened.

Next time I would check which API calls the Learner Lab denies before relying on a resource, and run a plan against production before the first approval. In a real AWS account I would use OIDC with the trust policy written in section 3, so there would be no session secrets to refresh. The biggest thing I now understand is that a failed apply leaves real resources and a partial state, so recovery means cleaning the state and redeploying, not just rerunning. The approval gate also holds production until a named reviewer acts, which gave me time to check the staging result first.

