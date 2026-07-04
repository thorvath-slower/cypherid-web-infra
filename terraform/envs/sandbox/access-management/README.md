# sandbox / idseq-support access-management — GitHub Actions build role

Provisions the **GitHub OIDC provider** and the **`gha-seqtoid` build role** in the
`idseq-support` / **sandbox** account (`941377154785`) so seqtoid-web's
`build-docker-image.yml` can log in to ECR and push the app image.

## Why this exists

`build-docker-image.yml` (auto on push to `main`) assumes
`arn:aws:iam::941377154785:role/gha-seqtoid`. That account had **no OIDC provider and
no such role**, so the assume-role was denied and the build fail-closed with nothing
pushed (this is the gap that blocked the deploy after the `integration → main` promotion).

> Note: `491013321714` (dev) already has its OIDC provider + `czid-dev-gh-actions-{plan,apply}`
> **deploy** roles (`dev/access-management`). This is the separate **build/registry** account.

## What it creates

- `aws_iam_openid_connect_provider.github` — `token.actions.githubusercontent.com`.
- `module.gha_seqtoid_build` → IAM role **`gha-seqtoid`**, trusting
  `repo:thorvath-slower/seqtoid-web:*` (any branch/tag/env for push-to-main + on-demand
  `workflow_dispatch`), with the module's C1 guard **denying `:pull_request`** subjects.
- `gha-seqtoid-ecr-push` policy — `ecr:GetAuthorizationToken` (account-wide, required for
  `docker login`) + image push/pull **scoped to `idseq-web` and `seqtoid-web` only**.
- No deploy / terraform / data permissions. Build-and-push only.

## How to apply (you — apply is held for everything else in this repo)

```bash
cd terraform/envs/sandbox/access-management
terraform init                 # backend: tfstate-941377154785-test, profile "default"
terraform plan                 # expect: 1 OIDC provider + 1 role + 1 policy + 1 attachment (all new)
terraform apply                # creates them in 941377154785
terraform output build_role_arn   # → arn:aws:iam::941377154785:role/gha-seqtoid
```

The AWS profile `default` must resolve to the `idseq-support` account (`941377154785`).

## After apply — no repo-variable change needed

`build-docker-image.yml` already defaults to `CI_ACCOUNT_ID=941377154785` and
`GHA_ROLE=gha-seqtoid`, so once this applies the next push to `main` (or a manual
`workflow_dispatch`) will assume the role, push to ECR, Trivy-scan, and cosign-sign.
To retarget elsewhere instead, set the repo Actions variables `CI_ACCOUNT_ID` / `GHA_ROLE`.

## Re-run the build after applying

Re-run the failed run, or trigger a fresh one:
```bash
gh workflow run build-docker-image.yml --repo thorvath-slower/seqtoid-web --ref main
```
Then watch it reach **Login to ECR → Build → Push → cosign** (previously all skipped).
