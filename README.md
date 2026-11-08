# Scoped or Spoofed — OIDC Trust Policy Demo Lab

This lab builds a single-account AWS environment for the talk "Scoped or
Spoofed: What a Missing OIDC Condition Really Costs You in AWS". It
replicates the three-step chain behind the UNC6426 cloud takeover:

1. A GitHub Actions workflow authenticates to AWS via OIDC.
2. The IAM role's trust policy checks the `aud` claim but has **no scoped
   `sub` condition** — so it trusts a valid OIDC token from *any* GitHub
   Actions workflow, not just the intended repository.
3. That role can call `cloudformation:CreateStack` with IAM capabilities —
   enough to create a brand-new administrator role and assume it.

> ⚠️ **WARNING — read before applying**
> This lab intentionally creates a role that can be assumed by an
> unintended GitHub repository and escalated to account admin. Only deploy
> it in a **dedicated, disposable AWS account** that holds no production or
> client data, and a **dedicated, disposable GitHub organization/account**
> you control end to end. Do not point this at your employer's or a
> client's GitHub org or AWS account. Tear it down as soon as you're done
> rehearsing or presenting.

## The scenario

```
legit-repo (intended)  ──┐
                          │   both present a valid GitHub OIDC token
spoof-repo (NOT intended) ┼──► IAM OIDC Provider (token.actions.githubusercontent.com)
                          │
                          ▼
                 DeployRole trust policy
                 checks: aud == sts.amazonaws.com
                 missing: sub condition  ◄── the gap
                          │
                          ▼
                 Both repos can assume DeployRole
                          │
                          ▼
         DeployRole can cloudformation:CreateStack
         with CAPABILITY_NAMED_IAM / CAPABILITY_IAM
                          │
                          ▼
         Stack creates a new role + AdministratorAccess
         DeployRole (or the workflow run) assumes it
                          │
                          ▼
                    ACCOUNT ADMIN
```

## What's in this repo

| Path | Purpose |
|---|---|
| `terraform/` | The OIDC provider, DeployRole (before/after trust policy), and its permissions |
| `cloudformation/` | The escalation payload: a CloudFormation template that creates an admin role |
| `github-actions/legit-repo/` | Workflow for the repository the role was meant for |
| `github-actions/spoof-repo/` | Workflow for a *different* repository, used to prove the trust policy doesn't actually restrict who can assume the role |
| `detection/` | EventBridge rule + SNS alert for the API calls this chain depends on |
| `scripts/` | Step-by-step demo script and a cleanup helper |

## Demo flow (matches the talk outline)

1. **Deploy the "before" infrastructure** (`terraform apply` with the
   vulnerable trust policy — the default state of `iam.tf`).
2. **Push `legit-repo`'s workflow** to its intended repository and confirm
   it can assume `DeployRole` and deploy the CloudFormation stack that
   creates an admin role. This is the "intended" path.
3. **Push `spoof-repo`'s workflow** to a *completely different*
   repository, and confirm it can **also** assume `DeployRole` — because
   the trust policy's `aud` condition says nothing about which repository
   is allowed. This is the gap the talk is about.
4. **Walk the chain**: show the new admin role the stack created, and
   assume it from the spoof repo's workflow.
5. **Apply the fix**: uncomment the scoped `sub` condition in
   `terraform/iam.tf` and re-apply.
6. **Re-run both workflows**: `legit-repo` still succeeds, `spoof-repo` now
   fails with `AccessDenied` on `sts:AssumeRoleWithWebIdentity`.
7. **Detection**: deploy `detection/` and re-run the attack path to show
   the alert firing on `AssumeRoleWithWebIdentity` from an unexpected
   subject, followed by `CreateStack`, `CreateRole`, and
   `AttachRolePolicy`.

## Before you present

- Run through the whole flow at least once end-to-end, including the
  "after" fix, in your own lab account and lab GitHub org.
- Confirm the spoof repo really can assume the role in the "before" state,
  and really cannot in the "after" state — don't assume it from reading
  the policy alone.
- CloudTrail → EventBridge delivery is not instant; budget a few minutes
  and have a pre-recorded fallback ready.
- Delete the GitHub OIDC provider's thumbprint caching isn't an issue here,
  but do rotate/delete the disposable repos and the OIDC provider when
  you're done, along with the AWS resources.
