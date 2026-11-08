# Scoped or Spoofed — OIDC Trust Policy Demo Lab

This lab builds a single-account AWS environment for the talk **"Scoped
or Spoofed: What a Missing OIDC Condition Really Costs You in AWS"**. It
demonstrates how a GitHub Actions OIDC trust policy that isn't scoped
tightly enough lets an unintended repository assume a role it was never
meant to use, and how that role's own permissions turn into a path to
full AWS admin.

> ⚠️ **WARNING — read before applying**
> This lab intentionally creates a role that can be assumed by an
> unintended GitHub repository and escalated toward account admin. Only
> deploy it in a **dedicated, disposable AWS account** that holds no
> production or client data, and a **dedicated, disposable GitHub
> organization/account** you control end to end. Tear it down as soon as
> you're done rehearsing or presenting.

## The scenario

```
legit-repo (intended)   ──┐
                          │   both present a valid GitHub OIDC token
spoof-repo (NOT intended) ┼──► IAM OIDC Provider (token.actions.githubusercontent.com)
                          │
                          ▼
                 DeployRole trust policy
                 checks: aud == sts.amazonaws.com
                 and: sub scoped to one exact repo + branch
                          │
                          ▼
         DeployRole can cloudformation:CreateStack
                          │
                          ▼
         Stack creates a new role + AdministratorAccess
                          │
                          ▼
                    ACCOUNT ADMIN
```

This repo is currently checked in with the trust policy in its **scoped
(fixed) state** — `sub` locked to one repo and branch via `StringEquals`
— and with `iam:CreateRole` / `iam:AttachRolePolicy` removed from
`DeployRole`'s own permissions. To reproduce the **vulnerable** state for
a live demo, see "Toggling between vulnerable and fixed" below.

## What's in this repo

| Path | Purpose |
|---|---|
| `terraform/main.tf` | Provider, variables (`aws_region`, `aws_profile`, `name_prefix`, `github_org`, `github_repo`, `legit_branch`) |
| `terraform/iam.tf` | The OIDC provider, `DeployRole` (trust policy + permissions), outputs |
| `cloudformation/admin-role-stack.yaml` | The escalation payload — a CloudFormation template that creates a same-account admin role |
| `detection/eventbridge.tf` | EventBridge rule + SNS alert for the API calls this chain depends on |
| `scripts/demo-steps.md` | Step-by-step walkthrough |
| `scripts/cleanup.sh` | Teardown helper |

## Related repositories

The GitHub Actions workflows that trigger this lab live in their own
repositories, not in this one:

- `legit-repo` — the intended deployment workflow
- `spoof-repo` — a different repository, used to prove the trust policy
  gap

(Add your actual repo links here once published.)

## Toggling between vulnerable and fixed

In `terraform/iam.tf`, the `aws_iam_role.deploy` trust policy's
`Condition` block currently has:
- An **active** `StringEquals` block scoping `sub` to one exact
  `repo:${github_org}/${github_repo}:ref:refs/heads/${legit_branch}`.
- A **commented-out** `StringLike` block with wildcard patterns, for the
  vulnerable state.

To demo the vulnerable path: comment out the `StringEquals` sub line,
uncomment the `StringLike` block, `terraform apply`, then reverse both to
show the fix.

Separately, `aws_iam_role_policy.deploy_permissions` currently has
`iam:CreateRole` and `iam:AttachRolePolicy` **commented out**. These must
be **uncommented** for `admin-role-stack.yaml` to deploy successfully at
all (it creates an `AWS::IAM::Role`) — see "Known gaps" below before you
rely on this for a live walkthrough.

## Known gaps (as of the current state of this repo)

These are called out explicitly rather than silently assumed to work —
confirm or fix each one before presenting:

- **`scripts/demo-steps.md` is out of date.** It still references
  `-var="legit_repo=..."`, but `terraform/main.tf` now defines separate
  `github_org` and `github_repo` variables instead. Commands in that file
  will fail as written until it's updated to match.
- **No `cloudformation/benign-stack.yaml`.** The talk's remediation
  segment depends on `legit-repo` being able to deploy *something* that
  doesn't require `iam:CreateRole`, so it still succeeds after that
  permission is removed from `DeployRole`. That template doesn't exist
  in this repo yet.
- **No cross-account parameter in `admin-role-stack.yaml`.** The role it
  creates only trusts the same account (`AWS::AccountId` root). If your
  presentation plan includes a cross-account persistence/backdoor demo,
  the template needs an `AttackerAccountId` parameter and a second trust
  statement — not present here yet.
- **This repo ships in the "fixed" state by default.** Anyone who clones
  it and runs `terraform apply` without first following "Toggling
  between vulnerable and fixed" above will get the secure configuration,
  not the vulnerable one used in the live attack demo.

## Before you present

- Run through the whole flow at least once end-to-end, including both
  states, in your own lab account and lab GitHub org.
- CloudTrail → EventBridge delivery is not instant; budget a few minutes
  and have a pre-recorded fallback ready.
- Rotate/delete the disposable repos and the OIDC provider when you're
  done, along with the AWS resources.
