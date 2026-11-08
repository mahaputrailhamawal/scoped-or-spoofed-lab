# Demo Steps — Scoped or Spoofed

Run these against a dedicated lab AWS account and a dedicated lab GitHub
organization you control. Replace placeholders with your own values.

## 0. Setup

```bash
cd terraform
terraform init
terraform apply \
  -var="legit_repo=<your-lab-org>/legit-repo" \
  -var="legit_branch=main"
terraform output
```

Note `deploy_role_arn`, `oidc_provider_arn`, and `account_id`.

Create two disposable repositories in your lab GitHub org/account:
- `legit-repo` — push the contents of `github-actions/legit-repo/` to it
- `spoof-repo` — push the contents of `github-actions/spoof-repo/` to it

Also copy `cloudformation/admin-role-stack.yaml` into `legit-repo` at the
path referenced by its workflow (`cloudformation/admin-role-stack.yaml`).

In **both** repos, set these repository secrets:
- `DEPLOY_ROLE_ARN` = the `deploy_role_arn` output (same value in both repos — this is the point)
- `AWS_REGION` = your lab region

## 1. Walking the Chain (vulnerable / "before" state)

```bash
# Trigger legit-repo's workflow (push to main, or workflow_dispatch)
gh workflow run deploy.yml --repo <your-lab-org>/legit-repo

# Confirm the stack deployed and created the escalated role
aws cloudformation describe-stacks --stack-name scoped-or-spoofed-demo \
  --query "Stacks[0].Outputs"

# Now trigger spoof-repo's workflow — a DIFFERENT repository, same role ARN
gh workflow run spoof.yml --repo <your-lab-org>/spoof-repo

# Watch the spoof run's logs: it successfully assumes DeployRole, and then
# assumes the escalated admin role the legit-repo workflow's stack created
gh run watch --repo <your-lab-org>/spoof-repo
```

At this point you've shown: a workflow in a repository that was never
meant to have access to this role can authenticate as it anyway, and walk
straight through to the admin role the legitimate deployment created.

## 2. Apply the fix

```bash
cd terraform
# In iam.tf, uncomment the sub condition line inside aws_iam_role.deploy
terraform apply \
  -var="legit_repo=<your-lab-org>/legit-repo" \
  -var="legit_branch=main"
```

## 3. Re-run both workflows

```bash
gh workflow run deploy.yml --repo <your-lab-org>/legit-repo
gh run watch --repo <your-lab-org>/legit-repo
# expect: still succeeds

gh workflow run spoof.yml --repo <your-lab-org>/spoof-repo
gh run watch --repo <your-lab-org>/spoof-repo
# expect: fails at "Configure AWS credentials via OIDC" with AccessDenied
```

## 4. Detection segment

```bash
cd ../detection
terraform init
terraform apply -var="alert_email=you@example.com"
```

Confirm the SNS subscription via email, then re-run step 1's sequence
again (you can re-apply the vulnerable trust policy temporarily if you
want to show the alert firing on a successful spoof, or trigger just the
legit workflow to show the detection also fires on normal, expected
activity — useful for discussing false positives in the "Lessons Learned"
segment). Budget a few minutes for CloudTrail → EventBridge delivery and
have the pre-recorded fallback ready.

## Cleanup

```bash
cd ../detection && terraform destroy
cd ../terraform && terraform destroy
```

Also delete `legit-repo` and `spoof-repo` from your lab GitHub org, or at
minimum remove their repository secrets and disable their workflows.
