# CZ ID web infrastructure — OpenTofu guide

This repo provisions the CZ ID stack's AWS infrastructure with
[OpenTofu](https://opentofu.org). It runs on **OpenTofu alone** — there is no
fogg, no Terragrunt, and no Terraform Cloud/Enterprise. Each stack is a plain
OpenTofu root module you run directly.

If you've used this repo before: the `terraform.tf` in each stack is now the
hand-maintained source of truth (it used to be the generated `fogg.tf`). See
[§9, What changed from the old setup](#9-what-changed-from-the-old-fogg--tfc-setup).

---

## 1. Repository layout

```
terraform/
  accounts/<account>/      # one per AWS account: bootstraps that account
  envs/<env>/<component>/   # the bulk of the infra, grouped by environment
  global/                  # account-agnostic, cross-cutting resources
  modules/<name>/          # reusable + vendored modules (used via source = "../...")
```

- **Environments**: `dev`, `staging`, `sandbox`, `prod`, `public`.
- **Component / stack**: a single directory with `*.tf` — its own state, its own
  backend, applied independently. "Stack" and "component" mean the same thing here.
- **Account**: bootstraps an AWS account (and creates that account's state bucket),
  so it uses a **local** backend (see [§4](#4-state-backend--locking)).

### Per-stack file anatomy

Every stack is a self-contained root module. Conventional files:

| File | Holds |
|------|-------|
| `terraform.tf` | The `terraform {}` block (backend + `required_version` + `required_providers`), the `provider` blocks, the standard input variables, and `data "terraform_remote_state"` references to upstream stacks. **This is the file the generator used to own; you now edit it directly.** |
| `main.tf` | The actual resources and module calls. |
| `variables.tf` | Stack-specific variables (beyond the standard ones in `terraform.tf`). |
| `outputs.tf` | Outputs other stacks consume via remote state. |
| `override.tf` | (accounts only) A native [override file](https://opentofu.org/docs/language/files/override/) switching the backend to `local` for bootstrap. |

---

## 2. Prerequisites

1. **OpenTofu**, pinned in [`.opentofu-version`](../.opentofu-version):
   ```bash
   brew install opentofu          # or: https://opentofu.org/docs/intro/install/
   tofu version                   # must satisfy the pin (>= 1.10 for state locking)
   ```
   To manage multiple versions, use [`tenv`](https://github.com/tofuutils/tenv),
   which reads `.opentofu-version` automatically.
2. **AWS CLI** with an `idseq-<env>` profile in `~/.aws/config` (see [§3](#3-credentials)).

There is **no** Docker, fogg, or tfenv requirement anymore.

---

## 3. Credentials

The stacks authenticate to AWS with the named profile declared in each
`terraform.tf` (`profile = "idseq-<env>"`). Configure SSO once, then refresh daily:

```bash
# one-time
aws configure sso --profile idseq-dev

# every day or so
aws sso login --profile idseq-dev
export AWS_DEFAULT_PROFILE=idseq-dev      # optional convenience
```

The `profile` is baked into both the backend and the provider blocks, so a plain
`tofu init && tofu plan` picks up the right credentials with no extra flags.

---

## 4. State backend & locking

Each stack stores its state in S3 under a **unique key**, declared inline in its
`terraform.tf`:

```hcl
terraform {
  backend "s3" {
    use_lockfile = true                                  # native locking, OpenTofu >= 1.10
    bucket       = "tfstate-<account-id>-..."
    key          = "terraform/idseq/envs/<env>/components/<component>.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-<env>"
  }
}
```

- **One key per stack** — never share a state file between stacks.
- **Locking** is `use_lockfile = true` — OpenTofu's native S3 lock (a `.tflock`
  object next to the state). No DynamoDB table is required, which keeps the
  pattern portable (it works the same on MinIO / an appliance). Concurrent applies
  are serialized; you'll see a clear lock error rather than corrupting state.
- **Backups** come from S3 bucket **versioning** — a bad apply is recoverable by
  restoring a prior object version. Do not add lifecycle rules that expire current
  versions.
- **Accounts use a `local` backend** (`override.tf`) because they *create* the
  state bucket — the classic bootstrap chicken-and-egg.

> Changing a backend (bucket/key) on an existing stack requires
> `tofu init -migrate-state`, which moves the state objects. That's a live
> operation — do it deliberately, with the team aware.

---

## 5. Day-to-day workflow

Work inside the stack you're changing:

```bash
cd terraform/envs/dev/auth0

tofu init           # once per checkout, and after any backend/provider change
tofu plan           # review the diff
tofu apply          # apply it
```

Repo-wide helpers (a thin native [`Makefile`](../Makefile), no fogg):

```bash
make fmt            # tofu fmt -recursive across the tree
make fmt-check      # formatting check (what CI runs)
make validate       # init -backend=false + validate every stack
make plan  DIR=terraform/envs/dev/auth0
make apply DIR=terraform/envs/dev/auth0
```

Formatting and validation also run in CI on every changed stack
([`.github/workflows/tofu_ci.yml`](../.github/workflows/tofu_ci.yml)). **There is
no auto-apply** — applies are always a deliberate human action.

---

## 6. Common tasks

### Change a resource
Edit the stack's `main.tf`, then `tofu plan` / `tofu apply` in that directory.

### Add a new component
1. `mkdir terraform/envs/<env>/<name>` and add `terraform.tf`, `main.tf`,
   `variables.tf`, `outputs.tf`. The fastest start is to copy a small existing
   component (e.g. `route53`) and adjust.
2. In `terraform.tf`, set a **unique** backend `key`
   (`.../components/<name>.tfstate`) and trim `required_providers` to what the
   stack actually uses.
3. `tofu init && tofu validate`, then `plan`.

### Reference another stack's output (dependency)
Stacks share data through remote state, not direct references:

```hcl
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket  = "tfstate-<account-id>-..."
    key     = "terraform/idseq/envs/<env>/components/route53.tfstate"
    region  = "us-west-2"
    profile = "idseq-<env>"
  }
}

# ... then consume it:
zone_id = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
```

Add an `output` to the upstream stack if the value you need isn't already exported.

### Bump a provider version across the repo
This is the one workflow that used to be a single edit in `fogg.yml`. Without a
generator you change the `required_providers` version in each stack's
`terraform.tf`. Because the blocks are identical, do it with a scripted edit and
review the diff, e.g.:

```bash
# example: aws ~> 5.100 -> ~> 5.110 everywhere
grep -rl 'source = "hashicorp/aws"' terraform --include='terraform.tf' \
  | xargs sed -i '' 's/version = "~> 5\.100\.0"/version = "~> 5.110.0"/'
make fmt && make validate
```

Then `tofu init -upgrade` per stack on the next apply. Keep the versions
consistent across stacks unless a stack genuinely needs to differ.

### Bootstrap a new environment
Apply in dependency order, starting from the account, then foundational
components, then the rest:

```bash
cd terraform/accounts/idseq-<env> && tofu apply && cd -
cd terraform/envs/<env>/iam-password-policy && tofu apply
# params-secrets -> route53 -> czid-services-private-key -> cloud-env ->
# idseq-s3-tar-writer -> elb-access-logs -> ... -> eks -> k8s-core -> happy
```

OpenTofu has no built-in "apply everything in order" command; apply stacks in the
order their `terraform_remote_state` dependencies imply.

---

## 7. Conventions

- **One stack = one directory = one state key.** Never point two stacks at the same key.
- **Keep `terraform.tf` uniform** across stacks (same provider/backend shape) so a
  scripted change stays a clean find-and-replace. CI `fmt-check` guards drift.
- **Pin `required_version` to `>= 1.6`** (`>= 1.10` for stacks using `use_lockfile`).
- **Licensing gate (Constitution Principle II):** only MPL / Apache-2.0 / BSD / MIT
  providers and modules — no BUSL/SSPL. Re-check when adding a dependency; see
  [`../specs/002-tofu-conversion/decisions/0001-licensing-gate.md`](../specs/002-tofu-conversion/decisions/0001-licensing-gate.md).
- **Least privilege (Principle VII):** deploy roles assume via GitHub OIDC (no
  static keys) and carry scoped policies — never `PowerUserAccess`/`*`.

---

## 8. CI/CD

[`tofu_ci.yml`](../.github/workflows/tofu_ci.yml) detects the stacks touched by a
push/PR and, for each, runs `tofu fmt -check` + `tofu init -backend=false` +
`tofu validate` using `opentofu/setup-opentofu` (pinned via `.opentofu-version`).
It does **not** apply. Applies are done deliberately — locally, or by a separate
gated deploy workflow you trigger on purpose.

---

## 9. What changed from the old fogg / TFC setup

This repo was previously generated by **fogg** and executed through **Terraform
Cloud/Enterprise**, with **Terragrunt** files for dependency metadata. All three
are removed. The infrastructure OpenTofu manages is unchanged; what changed is the
tooling around it:

| Was | Now | Notes |
|-----|-----|-------|
| `fogg.yml` → generated `fogg.tf` ("do not edit") | Hand-maintained `terraform.tf` | You own the files. Cross-cutting changes (e.g. provider bumps) are a scripted edit instead of `fogg apply` — see [§6](#bump-a-provider-version-across-the-repo). |
| `make setup` + tfenv (Terraform pin) | `brew install opentofu` / `tenv` + `.opentofu-version` | No generator install step. |
| Terragrunt `dependencies` metadata | `terraform_remote_state` only | Dependencies are still explicit in code; there's no `run-all`, so apply order is manual. |
| Terraform Cloud/Enterprise runs, UI, auto-apply, Sentinel | Local runs + GitHub Actions | Deliberate (Principle I — portability). Policy-as-code, if wanted, is OPA/conftest, not Sentinel. State was always in S3, so no state capability was lost. |

**Nothing about the AWS resources, providers, or modules changed** — only how the
repo is generated, orchestrated, and run.

---

## 10. Troubleshooting

- **`Error: Unsupported Terraform Core version` / version constraint** — your local
  `tofu` is older than the stack's `required_version` (`>= 1.10` where locking is
  on). Upgrade OpenTofu.
- **`Error acquiring the state lock`** — another apply holds the lock, or a previous
  run left a stale `.tflock` object. Confirm no one else is applying, then
  `tofu force-unlock <LOCK_ID>` if it's genuinely stale.
- **Init fails fetching a module over SSH (`git@github.com:...`)** — you need a
  GitHub SSH key in your agent (`ssh-add`, `ssh -T git@github.com`); some modules
  are pulled from private/SSH sources.
- **`Reference to undeclared local/resource` on a stack you didn't change** — a
  handful of components have pre-existing gaps in upstream history (e.g. missing
  `locals`); these predate the OpenTofu conversion and are tracked separately.
