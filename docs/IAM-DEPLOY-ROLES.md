# Deploy / CI IAM Roles — Least-Privilege (OPEN)

**Status: OPEN (P0).** Tracked as `IAM-1` (+ `CICD-1`) in the security review and
as the follow-up to `bug-#007`.

## Where
- `terraform/envs/dev/access-management/github-actions-runner-permissions.tf`
- `terraform/envs/staging/access-management/github-actions-runner-permissions.tf`
- (prod equivalent, when stood up)

## Background
`bug-#007` removed the AWS-managed **`PowerUserAccess`** policy from the dev/staging
GitHub Actions deploy roles. That stopped the bleeding (a near-admin role reachable
from CI) but it is **not the finished state** — removing a policy is not the same as
granting the *correct* minimal one, and history shows `PowerUserAccess` was
re-attached for the EKS path at one point. The role must end up with an explicit,
**least-privilege, customer-managed policy** scoped to exactly what the deploy
actually manages.

## What still needs to happen
1. **Replace, don't just remove.** Define a customer-managed IAM policy granting the
   *minimum* actions/resources the deploy role needs (derive it from a real
   `terraform plan`/`apply` of each component — e.g. the specific S3/EKS/IAM/RDS/ECR
   actions on the `cz-id`/`idseq-${env}-*` resources), and attach **that** instead of
   any managed `*FullAccess`/`PowerUserAccess`.
2. **Split read vs write (CICD-1).** A read-only **plan** role (`Describe*/Get*/List*`
   + state-bucket/lock read) for PR plans, and a separate **apply** role for the
   `workflow_dispatch`-only apply.
3. **Scope the OIDC trust policy.** Restrict `sub` to
   `repo:<org>/<repo>:ref:refs/heads/*` (and `:environment:*`), **never**
   `:pull_request`. Stop exporting credentials into env for plan jobs.
4. **Apply with a bootstrap admin profile.** A CI role cannot down-scope its own
   trust/permissions without risking mid-apply lockout — use the one-time admin
   identity (review foundation `F2`).

## Acceptance
- No `PowerUserAccess` (or any `*FullAccess`) attached to any CI/deploy role.
- Plan and apply use distinct roles; PR plans can't assume the apply role.
- OIDC trust policy denies `pull_request` subjects.
- `terraform plan` for every component still succeeds under the scoped policy.

See `TODO.md` for the one-line tracking entry.
