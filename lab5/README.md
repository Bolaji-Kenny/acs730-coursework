# Lab 5 (Week 6): Terraform network, validated in CI against LocalStack

One Terraform configuration that builds a VPC, two public subnets, an internet
gateway, a route table, a security group and a web server. A single variable,
`use_localstack`, switches it between real AWS and LocalStack.

## Layout

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider version constraints |
| `providers.tf` | AWS provider with the two-target switch |
| `variables.tf` | Typed, described variables (with validation blocks) |
| `network.tf` | locals, data sources, VPC, subnets (`for_each`), IGW, route table, security group (`dynamic "ingress"`), count-gated bucket |
| `compute.tf` | AMI data source and the web instance (`user_data`, explicit `depends_on`) |
| `outputs.tf` | `vpc_id`, `subnet_ids`, `web_public_ip`, `web_url`, `provider_target` |
| `localstack.tfvars` | Values that point the configuration at LocalStack |

## How to run it on the workstation (LocalStack)

```bash
docker run -d --name localstack -p 4566:4566 localstack/localstack:3.8.1
cd lab5
terraform init
terraform plan  -var-file=localstack.tfvars -out=tfplan
terraform apply tfplan
terraform output provider_target      # must say LocalStack, not REAL AWS
terraform destroy -var-file=localstack.tfvars -auto-approve
aws --endpoint-url http://localhost:4566 ec2 describe-vpcs
```

Always pass `-var-file=localstack.tfvars`. Without it `use_localstack` is
`false`, and a workstation with live credentials would plan a real VPC.

## Design note: why not run Terraform against real AWS on every pull request?

**Slow.** A real plan and apply creates a VPC, subnets, gateway and an EC2
instance, then waits for the instance to reach "running" and the destroy to
finish. That is minutes per run, multiplied by every push to every pull
request. Against LocalStack the same graph applies in seconds, so the check
fits inside a normal review loop.

**Expensive.** Real resources bill while they exist, and a failed or cancelled
run can leave them behind. An EC2 instance, public IPs and especially a NAT
gateway (about $32 a month) add up when every PR creates its own copy. In this
course the budget is a fixed $50 credit, so wasted runs are a direct loss.

**Flaky.** Real AWS adds failure modes unrelated to the code under review:
API rate limits, regional capacity, eventual consistency (a subnet that is not
visible yet), leftover resources from an earlier run that collide on names or
CIDR ranges, and quota limits. A red check that means "AWS was slow" teaches
reviewers to ignore red checks.

**Worse in an Academy account.** Academy credentials are temporary and expire
with the session, so a pipeline holding them fails on a schedule nobody
controls. Storing them as repository secrets means refreshing them by hand
before each run. The account also has a restricted IAM role, a fixed credit
balance and no way to create the permissions a CI identity would normally
use, so the pipeline cannot be set up the way it would be in a real account.
LocalStack removes credentials from the pipeline entirely: CI uses dummy
values, and nothing outside the runner can be changed or billed.

**What the LocalStack check does and does not prove.** It proves that the
configuration is syntactically valid, that the resource graph is coherent and
that the provider accepts every argument. It does not prove the deployment
works on real AWS: LocalStack does not enforce IAM and never runs `user_data`,
so a green run does not mean the web server boots or that permissions are
sufficient. Real-AWS validation stays a deliberate manual step, not a
per-commit one.

## Evidence

Files in `evidence/`:

- `ci-green.png`: a green `lab5-ci` run on a pull request showing both jobs
- `ci-failed.png`: the deliberately broken run, with the merge button disabled
- `describe-vpcs.txt`: output of the `describe-vpcs` teardown check
