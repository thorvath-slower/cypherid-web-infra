# Bug Specification: Provider-resolution outliers — prod/acm-validation & prod/s3-tf-state (bug-#014)

**Branch**: `bug-#014-provider-resolution`  ·  **Spec dir**: `specs/014-provider-resolution/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `cypherid-web-infra` (base: `improvement-#002-tofu-conversion`)

**Input**: Two prod stacks failed `tofu init`/`validate` against the standardized `aws ~> 5.100` provider pin — the conversion stragglers flagged in `docs/KNOWN-ISSUES.md`. Make them validate.

## Root causes (reproduced with OpenTofu 1.12.1)

**`prod/acm-validation`** — deprecated **inline provider `version` args** left over from the fogg/0.13-era config. `versions.tf` correctly pins `aws ~> 5.100.0` (and tls ~>3.0, random ~>3.4, null 3.1.1, archive ~>2.0, local ~>2.0), but `terraform.tf` *also* declared old versions inside the `provider` blocks (`aws ~> 3.5.0` ×3, `random ~> 2.2`, `archive ~> 1.3`, `null ~> 2.1`, `local ~> 1.4`, `tls ~> 2.1`). OpenTofu merges those as *additional* constraints, so the intersection is empty:
> `Could not resolve provider hashicorp/aws: no available releases match the given constraints ~> 3.5.0, ~> 5.100.0`

Plus a dead `provider "template"` block — deprecated provider, no `template_file` usage, not in `required_providers`, and unavailable for `darwin_arm64`.

**`prod/s3-tf-state`** — the cloudposse module used an **SSH source** (`git@github.com:cloudposse/terraform-aws-tfstate-backend?ref=1.4.0`) that can't fetch without an SSH key (breaks CI / fresh checkouts).

## Fixes

**`acm-validation/terraform.tf`**
- Removed all inline `version` args from the `provider` blocks — `required_providers` (versions.tf) is the single source of truth. Re-formatted with `tofu fmt`.
- Removed the dead `hashicorp/template` provider block.

**`s3-tf-state/main.tf`**
- Module source `git@github.com:…` → `github.com/cloudposse/terraform-aws-tfstate-backend?ref=1.4.0` (HTTPS git, no SSH key needed). **No version bump** — the 1.4.0 module already constrains aws `>= 4.9.0` (no upper bound), so it resolves `aws v5.100.0` cleanly. Keeping the version avoids an unvalidated module-schema change.

## Verification (OpenTofu 1.12.1, `init -backend=false` + `validate`)

- `acm-validation`: init resolves all providers (aws 5.100.0, okta 6.12.0, auth0 1.48.0, helm 2.17.0, kubernetes 3.1.0, kubectl 1.19.0, …); **`validate` → Success!**
- `s3-tf-state`: module fetches over HTTPS; `aws v5.100.0` installed against the module's `>= 4.9.0`; **`validate` → Success!**
- Both `tofu fmt`-clean. A repo-wide sweep found **no other** stacks with the inline-provider-version pattern (acm-validation was the last straggler).

## Notes

- This is the locally-verifiable class of the spawned task "Upgrade public env aws-3.x-era modules" (task_08485883) — resolved without touching prod state (init `-backend=false` only; live `apply` is Bucket B).
- Picked up by the `cypherid-web-infra` `tofu_ci.yml` (improvement-#002) once merged — these stacks will now pass the changed-stack validate gate.
