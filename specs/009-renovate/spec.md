# Improvement Specification: Renovate dependency automation (improvement-#009)

**Branch**: `improvement-#009-renovate`  ·  **Spec dir**: `specs/009-renovate/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `cypherid-web-infra` (base: `improvement-#002-terraform-conversion`)

**Input**: Extend the Renovate rollout to the web-infra deploy repo so its broad dependency surface is bot-maintained — and so the Docker digests pinned in `bug-#012` and the providers fixed in `bug-#014` stay current automatically. See `seqtoid-web` `specs/009-renovate/spec.md` for the full Renovate-vs-Dependabot rationale.

## What this delivers — `renovate.json` (repo root)

- `extends`: `config:recommended`, `:dependencyDashboard`, `:maintainLockFilesDisabled`.
- Weekly schedule (`before 9am on monday`, `America/Los_Angeles`); `prConcurrentLimit: 5`, `prHourlyLimit: 2`; `rebaseWhen: conflicted`; **`pinDigests: true`** (maintains the `bug-#012` `@sha256` pins on the grafana / idseq-s3-tar-writer bases).
- **`customManagers`** (regex): tracks **`.terraform-version`** against `hashicorp/terraform` releases.
- **Grouping** (`packageRules`) — important here because the repo has many env stacks:
  - **terraform providers** — provider/module bumps grouped into **one** PR instead of one per stack across the dozens of envs (the `terraform` manager reads `required_providers`: aws, auth0, helm, kubernetes, kubectl, okta, …).
  - **docker base images** — the two Dockerfiles (grafana, idseq-s3-tar-writer).
  - **pip deps** — `idseq-s3-tar-writer/requirements.txt`.
  - **github actions** — `terraform_ci.yml` + `argocd-ci.yml` actions.
- `vulnerabilityAlerts.enabled: true`.

## Validation

`renovate-config-validator` passes. Enabling the Renovate app on the repo is a GitHub-side step (Bucket B).

## Notes

- Grouping terraform provider updates is deliberate: an ungrouped run would open a PR per stack for the same `aws` bump. Majors still separate out (Renovate default) for review.
- The Argo CD Application manifests pin the argo-rollouts chart (`2.39.0`); tracking that via a Helm-source custom manager is a small possible follow-up.
