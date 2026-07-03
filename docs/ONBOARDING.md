# cypherid-web-infra — Onboarding Guide

A current-state, junior-engineer-friendly tour of this repo: what it is, what it
provisions, how it's organized, and how to make a change safely. Part of the
documentation epic (#394); tracked as #396.

If you only read one thing after this, read [`docs/TERRAFORM.md`](TERRAFORM.md) —
the deep-dive on the Terraform layer. This guide is the map; that one is the
manual. For the deploy layer, [`deploy/RUNBOOK.md`](../deploy/RUNBOOK.md).

---

## 1. Overview — what this repo is

This is the **infrastructure-as-code** for the **seqtoid / CZ ID** web
application (the platform is mid-rename from `cypherid`/`idseq` → `seqtoid`;
functional names that map to live AWS resources keep the legacy convention until
a coordinated cutover). It has two distinct halves:

| Half | Tech | Provisions |
|------|------|------------|
| **Terraform** (`terraform/`) | Plain Terraform on an S3 backend | The AWS foundation: accounts, networking (`cloud-env`), EKS clusters, databases (Aurora MySQL), Redis, IAM, Auth0, Route53, ACM, WAF, S3, params/secrets, the legacy ECS path, etc. |
| **Argo CD / GitOps** (`deploy/`) | Argo CD + Argo Rollouts, Helm | The **blue/green delivery** of the `seqtoid-web` app onto EKS — the app-of-apps, per-env Applications, and env values layered over the app's Helm chart. |

Key facts to internalize up front:

- **No fogg, no Terragrunt, no Terraform Cloud/Enterprise.** This repo used to be
  fogg-generated and run through TFC; all of that is gone. The `terraform.tf` in
  each stack is now a **hand-maintained** file you own and edit directly.
- **State lives in S3**, one key per stack, with native S3 locking
  (`use_lockfile = true`, no DynamoDB).
- **There is no auto-apply.** CI validates; humans apply. Applies are deliberate.
- **Some modules are vendored** (frozen in-tree copies) — see [§4](#4-modules).

---

## 2. Repo layout

```
cypherid-web-infra/
├── terraform/              # the AWS IaC (see §3)
│   ├── _shared/            # versions.tf — the ONE canonical provider/version file
│   ├── accounts/           # per-AWS-account bootstrap (local backend)
│   ├── envs/<env>/<stack>/ # the bulk of the infra, grouped by environment
│   ├── global/             # account-agnostic, cross-cutting resources
│   └── modules/            # reusable + vendored modules (used via source = "../...")
├── deploy/                 # GitOps / blue-green delivery (see §5)
│   ├── argocd/apps/        # per-env seqtoid-web Applications + controllers
│   ├── argocd/values/      # env value overlays for the app's Helm chart
│   ├── argocd/bootstrap/   # app-of-apps root-app.yaml (apply once)
│   ├── argocd/projects/    # the czid AppProject
│   └── RUNBOOK.md          # how to deploy / promote / roll back
├── .github/workflows/      # CI: terraform-ci, security, argocd-ci, deploy/promote (see §6)
├── .github/actions/        # terraform-validate composite action
├── amis/                   # Packer AMIs for the on-call / comp-bio individual-attr hosts
├── docker/                 # grafana provisioning
├── specs/                  # design specs & decision records (002-terraform-conversion, etc.)
├── docs/                   # this guide, TERRAFORM.md, IAM-DEPLOY-ROLES.md
├── Makefile                # thin wrappers: make fmt / validate / plan / apply / check
├── bin/check               # run the CI checks locally (== a green CI predictor)
├── .terraform-version      # pinned Terraform version (currently 1.15.7)
├── .checkov.baseline       # 259 inherited checkov findings accepted; gate on NEW only
├── .trivyignore / .gitleaks.toml
└── README.md               # quick start
```

---

## 3. Environments & stacks

### The unit of work: a stack (= component)

A **stack** (also called a "component") is a single directory under `terraform/`
containing `*.tf`. It has **its own state, its own S3 backend key, and is applied
independently**. You never apply "the whole repo"; you `cd` into a stack and run
Terraform there.

```bash
cd terraform/envs/dev/auth0
terraform init      # once per checkout, and after any backend/provider change
terraform plan      # review the diff
terraform apply     # apply it
```

### Environments

| Env | Path | Notes |
|-----|------|-------|
| `dev` | `terraform/envs/dev/` | Primary iteration env; first successful drop-in deploy target. |
| `staging` | `terraform/envs/staging/` | Mirrors dev; second promotion tier. |
| `prod` | `terraform/envs/prod/` | Mirrors dev/staging; manual gate. |
| `sandbox` | `terraform/envs/sandbox/` | Slimmer set; not in the mirror chain. |
| `public` | `terraform/envs/public/` | Legacy aws-3.x-era stacks (module-upgrade debt). |

**`dev`, `staging`, and `prod` are strict mirrors** — the same set of stacks
exists in each, and CI validates every env a stack lives in whenever you touch it
in any one of them (drift guard, see [§6](#6-ci-gates)). `sandbox` and `public`
are non-mirrored and validated as a flat matrix.

### Common stacks (what they provision)

Present across dev/staging/prod (a representative slice — see the directory
listing for the full set):

| Stack | What it does |
|-------|--------------|
| `cloud-env` | Base networking / the `aws-env` foundation. |
| `eks` | The EKS cluster (where `seqtoid-web` runs via Argo CD). |
| `db` | Aurora MySQL (the app hard-requires MySQL 8). |
| `redis` | ElastiCache Redis replication group. |
| `auth0` | Auth0 tenant config. |
| `route53` / `acm-validation` / `web-waf` | DNS, certs, WAF. |
| `params-secrets` | The org-wide SSM params + secrets scaffolding (see [§7](#7-secrets--params-flow)). |
| `access-management` | GitHub Actions OIDC deploy roles + IAM (see [`IAM-DEPLOY-ROLES.md`](IAM-DEPLOY-ROLES.md)). |
| `ecs` / `web` | The **legacy** ECS/ALB app path (pre-EKS). |
| `k8s-core` / `happy` | Kubernetes core add-ons and the happy env wiring. |
| `otel` | OpenTelemetry collector. |

### Accounts (bootstrap)

`terraform/accounts/idseq-{dev,staging,prod,support}` bootstrap each AWS account
and **create that account's state bucket**. Because of the bootstrap
chicken-and-egg, accounts use a **local** backend (via an `override.tf`), unlike
every other stack.

### Per-stack file anatomy

| File | Holds |
|------|-------|
| `versions.tf` | A **symlink** to `terraform/_shared/versions.tf` — the one canonical `required_version` + `required_providers`. Don't edit the per-stack copy. |
| `terraform.tf` | The `backend "s3"` block (unique state `key` + shared settings), `provider` blocks, standard input vars, and `terraform_remote_state` refs to upstream stacks. |
| `main.tf` | The actual resources / module calls. |
| `variables.tf` / `outputs.tf` | Stack-specific vars; outputs other stacks consume. |
| `override.tf` | (accounts only) switches the backend to `local` for bootstrap. |

**Cross-stack dependencies** are expressed with `data "terraform_remote_state"` —
a stack reads an upstream stack's outputs directly from its S3 state. There is no
`run-all`; **apply order is manual**, in the order the remote-state deps imply.

---

## 4. Modules

Reusable and vendored modules live in `terraform/modules/`, consumed by a
**local relative path**: `source = "../../../modules/<name>"`.

### Vendored cztack modules (frozen snapshots — human-maintained)

Most modules are **in-tree copies** of `chanzuckerberg/shared-infra` (cztack)
modules. That upstream repo is **inaccessible to our org**, so the modules were
copied in-house (CZID-90). You can spot them by the **version suffix** in the dir
name — e.g. `aws-aurora-mysql-v0.104.2`, `ecs-cluster-v2.2.1`,
`ecs-service-with-alb-v0.421.0`, `aws-params-secrets-setup-v0.104.2`. The `main.tf`
of a consumer typically carries a `# cztack v0.104.2` comment.

Two consequences you must know:

- **Renovate cannot update them.** A local-path `source` has no upstream
  datasource, so there is no "new version" to bump. The vendored HCL is **frozen**
  at the version it was copied at. (Renovate *does* manage everything else:
  provider constraints, external `?ref=` module pins, Actions, Docker digests.)
- **Updating one is a manual re-vendor**, not a version bump — copy the new
  version alongside as `<name>-v<newver>/`, repoint consumers one at a time,
  review each `terraform plan`, then delete the old dir. Full procedure in
  [`TERRAFORM.md` → Update a vendored module](TERRAFORM.md#update-a-vendored-module).

Some vendored dirs (those with relative `../` sub-module deps or the `template`
provider — e.g. `ecs-cluster-v2.2.1`, `ecs-service-with-alb-v0.421.0`) **can't
validate standalone** and are listed in
[`.github/terraform-ci-skip.txt`](../.github/terraform-ci-skip.txt). They're
validated **transitively** through the stacks that consume them.

### The single source of truth for versions

`terraform/_shared/versions.tf` is the **one file** declaring the Terraform
version and every provider constraint. It's symlinked into each stack as
`versions.tf`, so a provider bump is **one edit** that moves every stack together
— zero drift. Niche providers (`hashicorp/template`, `hashicorp/cloudinit`) are
declared **only** in the modules that need them, never in `_shared`, because
`template` has no `darwin_arm64` build and would break `terraform init` repo-wide
on Apple Silicon (CZID-130).

---

## 5. Deploy layer — Argo CD blue/green (`deploy/`)

The `seqtoid-web` app is delivered onto EKS via **Argo CD + Argo Rollouts**, not
by Terraform. This is the GitOps half.

### Multi-source Applications (chart here, values there)

Each per-env Application (`deploy/argocd/apps/seqtoid-web-<env>.yaml`) is
**multi-source**:

- **Source 1 — the Helm chart** comes from the **app repo**
  (`seqtoid-web`, path `deploy/charts/seqtoid-web`), so the chart versions with
  the code.
- **Source 2 — the env values** come from **this repo**
  (`deploy/argocd/values/seqtoid-web/<env>.yaml`), referenced as `$values`, so
  deploy config versions independently of the code.

### App-of-apps

`deploy/argocd/bootstrap/root-app.yaml` (`czid-root`) is applied **once** after
Argo CD is installed. It then manages everything under `deploy/argocd/apps/`
(the Argo Rollouts controller, the AWS Load Balancer Controller, and the per-env
`seqtoid-web` Applications). Add a new managed app by dropping a manifest into
`apps/`. The `czid` AppProject is in `deploy/argocd/projects/czid.yaml`.

### Blue/green flow (summary — full runbook in `deploy/RUNBOOK.md`)

1. CI advances `image.tag` in the env's `values/.../<env>.yaml`.
2. Argo CD syncs; Argo Rollouts brings up the **preview** color beside the live
   **active** color (no traffic shift yet).
3. A **smoke `AnalysisRun`** hits the preview (`/health_check` + `smoke.paths`);
   failure **auto-aborts and rolls back** — active never changed.
4. **Promotion gate:** `dev`/`staging` auto-promote on smoke pass
   (`autoPromotionEnabled: true`); **prod pauses for a manual promote**
   (`autoPromotionEnabled: false`).
5. On promotion, traffic switches; the old color drains for
   `scaleDownDelaySeconds` then scales down.

Day-2 commands use the `kubectl argo rollouts` plugin (`get --watch`, `promote`,
`abort`, `undo`) — see the runbook.

> The env values files ship with `REPLACE_*` placeholders (account IDs, ECR
> repos, IRSA role ARNs, cert ARNs, subnets, DNS host). Filling those in with the
> real per-env values is part of standing up a live deploy.

---

## 6. CI gates

All CI is in `.github/workflows/`. The gates you'll meet on a PR:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **`terraform_ci.yml`** (`terraform-ci`) | PR / push to `main` / merge_group | Detects changed stacks, groups them into concurrent **buckets** (one per mirrored stack, one for the accounts trio, one flat "rest"), and runs `fmt -check` + `init -backend=false` + `validate` per stack. Mirrored buckets chain **dev → staging → prod**. **No apply.** Skips `terraform-ci-skip.txt` (vendored) and `terraform-ci-quarantine.txt` (known-defect) stacks. |
| **`security.yml`** | PR / push / merge_group | Calls the shared SSOT reusable `thorvath-slower/seqtoid-ci-workflows/.../security.yml@v1`. Runs **checkov** (hard-fail on findings **not** in `.checkov.baseline`), **tflint**, **trivy** (vuln-only — the full-tree TF misconfig scan hangs on this repo's large module graph; misconfig is covered by tflint + checkov), and **gitleaks**. |
| **`argocd-ci.yml`** | changes under `deploy/argocd/**` | Schema-validates every Argo manifest against the Argo CRD schemas (kubeconform); asserts the per-env promotion gates (dev/staging auto, prod manual, analysis on everywhere) and the LB wiring. A gated `chart` job (on `vars.CHART_CI_ENABLED`) checks out the **real** chart from the app repo, `helm template`s it against these values, and validates the Rollout/AnalysisTemplate output. |
| **`actionlint.yml`** | workflow changes | Lints the workflow YAML. |
| `plan_all` / `apply_all` / `deploy_env` / `promote` / `apply_component_call` / `plan_component_call` | `workflow_dispatch` | The deliberate **deploy** workflows (not PR gates). `promote.yml` enforces **dev → staging → prod** ordering (prod unreachable unless dev+staging went green; CZID-96). Applies use **GitHub OIDC** roles (no static keys). |

**Local parity:** `make check` (→ `bin/check`) runs `fmt-check` + `validate` +
the security scanners locally, mirroring CI. A green `make check` predicts a green
CI (CZID-311). Install the tools with `brew install terraform trivy tflint gitleaks`.

---

## 7. How to make a change

### Terraform change

1. **Branch off `integration`** (this repo's working base for the fork):
   `git checkout -B <ticket>-<slug> origin/integration`.
2. **Edit the stack.** `cd terraform/envs/<env>/<stack>`, change `main.tf` (or the
   relevant file). If it's a mirrored stack, remember the change likely needs to
   land in dev/staging/prod together.
3. **Validate locally:** `make check` (or at minimum `make fmt` + `make validate`).
4. **Plan** (needs AWS creds): `aws sso login --profile idseq-<env>`, then
   `terraform plan` in the stack (or `make plan DIR=terraform/envs/<env>/<stack>`).
5. **Open a small, single-concern gated PR** against `integration`. CI runs
   `terraform-ci` + `security` (+ `argocd-ci` if you touched `deploy/`).
   **Do not merge without sign-off.**
6. **Apply is deliberate** — locally, or via the gated deploy/promote workflows.
   Never rely on CI to apply.

### Deploy-config change (Argo values)

Edit `deploy/argocd/values/seqtoid-web/<env>.yaml`, open a PR — `argocd-ci`
schema-validates and asserts the promotion/LB invariants. Argo CD syncs the merge.

### Doctrine (from team memory)

- **Small, single-concern PRs.** No bundling; keep changes traceable.
- **Validate locally in Docker/`make check` before pushing** — CI is the final
  gate, not the dev loop.
- **Never downgrade a dep to dodge a conflict** — bump the toolchain forward and
  file a ticket.
- **Never rename an existing object/identifier** — the new thing gets the new
  name; note it. (Avoids breaking existing consumers.)
- **Least privilege:** deploy roles assume via GitHub OIDC (no static keys) with
  scoped policies — never `PowerUserAccess`/`*` (see `IAM-DEPLOY-ROLES.md`).

---

## 8. Runbook / gotchas

**Common operations**

| I want to… | Do this |
|------------|---------|
| Change a resource | Edit the stack's `main.tf`; `plan`/`apply` in that dir. |
| Add a new component | `mkdir terraform/envs/<env>/<name>`, add `terraform.tf` (unique backend `key`!), symlink `versions.tf` from `_shared`, `init && validate`. See `TERRAFORM.md §6`. |
| Reference another stack's output | Add a `data "terraform_remote_state"` block; add the `output` upstream if missing. |
| Bump a provider repo-wide | Edit **one** file, `terraform/_shared/versions.tf`; `make validate`; `terraform init -upgrade` per stack on next apply. |
| Update a vendored module | Manual re-vendor (see [§4](#4-modules) / `TERRAFORM.md`). |
| Deploy / promote / roll back the app | `deploy/RUNBOOK.md` (`kubectl argo rollouts …`). |
| Run CI checks locally | `make check`. |

**Gotchas**

- **`Error acquiring the state lock`** — another apply holds it, or a stale
  `.tflock` object remains. Confirm no one is applying, then
  `terraform force-unlock <LOCK_ID>` only if genuinely stale.
- **`Unsupported Terraform Core version`** — your local `terraform` is older than
  the stack's `required_version` (`>= 1.10` where S3 locking is on; repo pins
  `1.15.7` in `.terraform-version`). Upgrade / use `tenv`.
- **`Failed to resolve provider packages` / a split constraint like
  `aws ~> 3.5.0, ~> 5.100.0`** — a **module** in that stack pins an older
  provider than `_shared`. Fix the module forward; **don't** downgrade the shared
  file. The `public` env currently trips this (aws-3.x-era modules — tracked debt).
- **Module init fails over SSH (`git@github.com:...`)** — you need a GitHub SSH
  key in your agent (`ssh-add`, `ssh -T git@github.com`).
- **A stack you didn't touch fails CI** — check `terraform-ci-skip.txt`
  (vendored/inaccessible) and `terraform-ci-quarantine.txt` (known pre-existing
  defects, CZID-91/92/93); those are excluded on purpose so they don't block you.
- **checkov flags something** — new findings hard-fail; inherited ones live in
  `.checkov.baseline` (259 accepted, CZID-264). Don't remediate baseline findings
  as part of unrelated work.

---

## 9. Where things live (quick index)

| I'm looking for… | It's here |
|------------------|-----------|
| The Terraform deep-dive | [`docs/TERRAFORM.md`](TERRAFORM.md) |
| Deploy roles / least-privilege state | [`docs/IAM-DEPLOY-ROLES.md`](IAM-DEPLOY-ROLES.md) |
| Blue/green deploy runbook | [`deploy/RUNBOOK.md`](../deploy/RUNBOOK.md) |
| Argo CD bootstrap instructions | [`deploy/argocd/bootstrap/README.md`](../deploy/argocd/bootstrap/README.md) |
| The one provider/version file | [`terraform/_shared/versions.tf`](../terraform/_shared/versions.tf) |
| Per-env Argo values | `deploy/argocd/values/seqtoid-web/<env>.yaml` |
| Per-env Argo Applications | `deploy/argocd/apps/` |
| CI workflows | `.github/workflows/` |
| Stacks CI can't validate standalone | `.github/terraform-ci-skip.txt` |
| Quarantined (known-defect) stacks | `.github/terraform-ci-quarantine.txt` |
| Design specs / decision records | `specs/` (e.g. `002-terraform-conversion`, `002-blue-green-delivery`) |
| Local CI parity script | `bin/check` (`make check`) |
