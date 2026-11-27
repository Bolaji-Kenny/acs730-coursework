#!/usr/bin/env bash
#
# evidence.sh -- capture the text evidence files with the exact names the
# rubric looks for. Run from anywhere inside the repository on the workstation.
#   ./assignment1/scripts/evidence.sh state-keys | environments | secrets-scope | ssm | alarm
# 2>&1 is deliberate: a command that writes to stderr must not leave a zero-byte file.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

EV=assignment1/evidence
BUCKET=acs730-tfstate-224364172046
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
mkdir -p "$EV"

case "${1:-}" in
  state-keys)
    { date; aws s3 ls "s3://${BUCKET}/assignment1/" --recursive; } 2>&1 | tee "$EV/backend-state-keys.txt"
    ;;
  environments)
    gh api "repos/${REPO}/environments" 2>&1 | tee "$EV/environments.json"
    ;;
  secrets-scope)
    {
      date
      echo "== repository-level secrets (must list none of the three AWS names) =="
      gh secret list --repo "$REPO"
      echo "== staging environment secrets =="
      gh secret list --env staging --repo "$REPO"
      echo "== prod environment secrets =="
      gh secret list --env prod --repo "$REPO"
    } 2>&1 | tee "$EV/secrets-scope.txt"
    ;;
  ssm)
    {
      date
      echo "== Terraform side: one data source, no resource =="
      grep -rn "aws_ssm_parameter" assignment1/terraform --include=*.tf
      for e in staging prod; do
        echo "== ${e}: parameter Terraform read =="
        terraform -chdir="assignment1/terraform/${e}" init -input=false >/dev/null 2>&1
        terraform -chdir="assignment1/terraform/${e}" output ssm_parameter_arn
        terraform -chdir="assignment1/terraform/${e}" output ssm_parameter_version
        aws ssm get-parameter --region us-east-1 --name "/acs730/assignment1/${e}/db_password" \
          --query 'Parameter.{Name:Name,Type:Type,Version:Version}' --output table
      done
    } 2>&1 | tee "$EV/ssm-parameter.txt"
    ;;
  alarm)
    aws cloudwatch describe-alarms --region us-east-1 --alarm-name-prefix acs730-a1- --output json \
      2>&1 | tee "$EV/cloudwatch-alarm.json"
    echo
    aws cloudwatch describe-alarms --region us-east-1 --alarm-name-prefix acs730-a1- \
      --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Metric:MetricName}' --output table
    ;;
  *)
    echo "usage: $0 state-keys|environments|secrets-scope|ssm|alarm" >&2
    exit 2
    ;;
esac
