#!/usr/bin/env bash
#
# destroy-all.sh -- Task 9. Destroys prod, staging and dev (in that order),
# writes everything to assignment1/evidence/destroy-complete.txt, then removes
# the out-of-band SSM parameters and runs cleanup-check.sh.
# Destroy prints once, so this tees the whole run. Needs the lab session started.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
OUT=assignment1/evidence/destroy-complete.txt
mkdir -p assignment1/evidence

{
  date
  for env in prod staging dev; do
    echo "=================== destroy ${env} ==================="
    terraform -chdir="assignment1/terraform/${env}" init -input=false
    terraform -chdir="assignment1/terraform/${env}" destroy -input=false -auto-approve
  done

  echo "=================== remove SSM parameters ==================="
  for env in dev staging prod; do
    aws ssm delete-parameter --region us-east-1 --name "/acs730/assignment1/${env}/db_password" \
      && echo "deleted /acs730/assignment1/${env}/db_password"
  done

  echo "=================== cleanup-check ==================="
  ./scripts/cleanup-check.sh
} 2>&1 | tee "$OUT"

echo
echo "Saved to $OUT -- read the cleanup-check section above before you stop."
