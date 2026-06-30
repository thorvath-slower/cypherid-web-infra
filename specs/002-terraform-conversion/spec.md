# Improvement Specification: Terraform → Terraform Conversion

**Branch**: `improvement-#002-terraform-conversion`  ·  **Spec dir**: `specs/002-terraform-conversion/`

**Created**: 2026-06-10 · **Status**: Draft · **Repo**: `cypherid-web-infra`

**Input**: Move `cypherid-web-infra` off Terraform and onto Terraform, cut the Terraform Cloud/Enterprise coupling, point state at the shared foundation backend with locking on, and tighten the deploy IAM — all without changing what the infrastructure *does*.

## Why

We're standardizing the whole CZ ID stack on **Terraform** (Constitution Principle II — no BUSL/SSPL in the shipped product). `cypherid-web-infra` is a `fogg`-generated Terraform repo that today pins an exact Terraform version, runs through Terraform Cloud workspaces, and stores state in per-account S3 buckets with locking disabled in two environments. None of that survives the portability bar, so this slice does the engine swap and closes the state-locking gap (`bug-#006`) and the over-broad deploy role (`bug-#007`) on the way through.

This is an **improvement, not a feature**: behavior is preserved (Principle VIII). The only things that change are the engine, the run platform, the state location, and the blast radius of the deploy credentials — never the resources themselves.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The repo runs on Terraform, not Terraform (Priority: P1)

As a platform engineer, every component and module in `cypherid-web-infra` initializes and validates under Terraform, so we own the engine and ship nothing BUSL-encumbered.

**Why this priority**: Everything else in the conversion depends on the engine actually accepting the configuration.

**Independent Test**: `terraform init -backend=false && terraform validate` succeeds in a representative set of components (e.g. `envs/dev/auth0`) and our own modules, with no `required_version` rejection.

**Acceptance Scenarios**:
1. **Given** a converted component, **When** `terraform validate` runs, **Then** it passes with no version-constraint error and no deprecation warnings we introduced.
2. **Given** the dependency set, **When** licensing is reviewed at the plan gate, **Then** no provider or module is BUSL/SSPL (Principle II). See `decisions/0001-licensing-gate.md`.

### User Story 2 - No Terraform Cloud/Enterprise dependency (Priority: P1)

As the portable product, the stack has no hard dependency on Terraform Cloud/Enterprise, so it can run from a laptop, from GitHub Actions, or air-gapped (Principle I).

**Why this priority**: TFC/TFE is a single-vendor SaaS run platform; it cannot exist in the appliance path.

**Independent Test**: No `tfe` provider, no `terraform/tfe` component, and no `TFC_*` runtime variables remain; `terraform validate` still passes.

**Acceptance Scenarios**:
1. **Given** the converted repo, **When** we grep for `hashicorp/tfe` and `TFC_WORKSPACE`, **Then** there are no matches in the run path.
2. **Given** a component apply, **When** it tags resources, **Then** tagging no longer depends on TFC-injected variables.

### User Story 3 - State lives in the shared backend, locked (Priority: P1)

As the platform, all state is in the shared foundation backend under one key per stack, with locking on, so we never lose or corrupt state and never duplicate the foundation (`feature-#001`, `bug-#006`).

**Why this priority**: Two environments currently run with `dynamodb_enabled: false` — i.e. no state locking at all. Concurrent applies can corrupt state.

**Independent Test**: A converted component reads `data.terraform_remote_state.foundation` outputs read-only and its backend config carries a lock mechanism (`use_lockfile` or DynamoDB).

**Acceptance Scenarios**:
1. **Given** a converted component, **When** it inits, **Then** its state key is unique per stack and locking is enabled.
2. **Given** a value owned by the foundation, **When** a component needs it, **Then** it reads a foundation output rather than redefining the resource.

### User Story 4 - Least-privilege deploy credentials (Priority: P2)

As a security reviewer, the deploy role is scoped and prefers GitHub OIDC over static keys (`bug-#007`, Principle VII).

**Independent Test**: The deploy path uses the foundation's `shared_iam_role_arns["gha-deploy"]` (OIDC) or a role scoped to named ARNs, never `*`.

## Requirements *(mandatory)*

- **FR-001**: Every `required_version` constraint MUST admit the pinned Terraform version; no exact Terraform pins (`=1.14.8`, `=1.3.6`) or floors above the running tool (`>= 1.14.8`, `~> 0.12.24`).
- **FR-002**: `fogg` MUST be removed entirely — no `fogg.yml`, no `fogg.tf`, no fogg headers, no fogg build scripts or CI. The previously-generated files become hand-maintained native Terraform (the `terraform.tf` in each stack is the source of truth). The repo MUST run on Terraform alone, with no generator and no Terraform Cloud/Enterprise.
- **FR-003**: The dependency set MUST contain only MPL/Apache/BSD/MIT licenses (Principle II).
- **FR-004**: The `tfe` provider, the `terraform/tfe` component, and all `TFC_*` runtime variables MUST be removed from the run path.
- **FR-005**: All CLI tooling (Makefiles, `scripts/*.mk`, CI) MUST invoke `terraform`, not `terraform`.
- **FR-006**: Each stack's state MUST use a unique key with locking enabled (`bug-#006`).
- **FR-007**: Components MUST inherit shared infrastructure from `data.terraform_remote_state.foundation` outputs, never redefine it.
- **FR-008**: The deploy role MUST be least-privilege and prefer OIDC over static credentials (`bug-#007`).
- **FR-009**: Application behavior MUST be unchanged (Principle VIII); resource definitions are not altered except where required by the engine swap itself.
- **FR-010**: Provider/version constraints MUST come from a **single source of truth** — one canonical `terraform/_shared/versions.tf` symlinked into every root stack — so a version bump is one edit and stacks cannot drift (Principle III). Modules keep their own minimal `versions.tf`.

## Success Criteria *(mandatory)*

- **SC-001**: `terraform validate` is clean on all of our own modules and on representative components (those whose modules resolve without private/SSH fetch).
- **SC-002**: Zero BUSL/SSPL in the dependency set, documented at the plan gate.
- **SC-003**: Zero `hashicorp/tfe` / `TFC_*` references in the run path.
- **SC-004**: Every backend config has a lock mechanism; no stack shares a state key.
- **SC-005**: Zero fogg residue — `git grep -i fogg` returns only intentional migration notes (this spec + the README history line); no `fogg.yml`/`fogg.tf`/fogg headers/fogg scripts/fogg CI remain, and the repo builds and validates with `terraform` alone.

## Out of Scope / Bucket B (Tom, live env)

- Live `terraform init -migrate-state` to move state objects into the shared foundation bucket, and any `terraform plan`/`apply`.
- **FR-007 (foundation inheritance) is deferred.** This repo owns its own infra (`cloud-env`, `eks`, …) under per-account state buckets; rewiring every stack to read `data.terraform_remote_state.foundation` outputs and consolidating those buckets into the shared foundation bucket is a large refactor that presupposes the foundation is applied and a live state migration. Per-stack keys and locking (FR-006) are done; the foundation-inheritance rewiring is teed up as follow-up work.
- Generalizing Auth0 into the OIDC boundary — that is `feature-#004`, not this slice. Here we only convert the existing Auth0 components, behavior-preserved.
- Fetching/validating components that depend on private or `git@`-SSH module sources, which need credentials this environment doesn't have.

## Notes

**fogg fully removed.** Rather than keep `fogg` (v0.92.46) as the generator and re-point it at Terraform, we removed it outright — the repo now runs on Terraform alone. This dissolves the regeneration hazard that an earlier draft of this spec flagged (a `fogg apply` re-introducing the exact version pin and `TFC_*` coupling and reverting the conversion): there is no longer a generator to run, and the `fogg-apply` CI job is gone. Removed in this slice:

- `fogg.yml`, `.fogg-version`, every `fogg.tf` (renamed to `terraform.tf`), `fogg_override.tf` (→ native `override.tf`), and all "Auto-generated by fogg" headers.
- All 90 `terragrunt.hcl` (ordering is expressed via `terraform_remote_state`), all 123 fogg `Makefile`s and the `scripts/*.mk` + fogg helper scripts.
- The `fogg_ci.yml` workflow, replaced by `tofu_ci.yml` (native `terraform fmt -check` + `validate` on changed stacks; no auto-apply).

The per-stack `terraform.tf` (backend + providers + versions + variables + remote-state) is now the hand-maintained source of truth, and a thin native `Makefile` provides `fmt`/`validate`/`plan`/`apply` helpers.

**Not removed (out of scope, not fogg):** the `blessconfig.yml` / blessclient SSH-CA setup is CZI bastion tooling, independent of fogg; left as-is and noted for a later portability pass.
