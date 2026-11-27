#!/usr/bin/env bash
#
# put-parameters.sh -- the documented pre-step for Task 6.
# Creates the placeholder DB password parameter for each environment, ONCE,
# out of band. Terraform only READS these through a data source and never
# creates them. Run on the workstation with the lab session started.

set -euo pipefail

for env in dev staging prod; do
  aws ssm put-parameter \
    --region us-east-1 \
    --name "/acs730/assignment1/${env}/db_password" \
    --type SecureString \
    --value "placeholder-${env}-not-a-real-password" \
    --overwrite >/dev/null
  echo "created /acs730/assignment1/${env}/db_password"
done
