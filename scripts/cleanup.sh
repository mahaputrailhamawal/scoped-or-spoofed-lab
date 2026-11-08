#!/usr/bin/env bash
# Tears down the lab. Run from the repo root.
set -euo pipefail

echo "This will destroy the detection stack and the lab stack."
read -p "Type 'destroy' to continue: " confirm
if [ "$confirm" != "destroy" ]; then
  echo "Aborted."
  exit 1
fi

( cd detection && terraform destroy )
( cd terraform && terraform destroy )

echo "Done. Remember to also:"
echo "  - delete the escalated admin role's CloudFormation stack if it's still around"
echo "  - delete or disable the legit-repo and spoof-repo GitHub repositories"
echo "  - remove their DEPLOY_ROLE_ARN / AWS_REGION secrets"
