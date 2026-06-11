# Improvement Specification: Security scanning CI (improvement-#010)

**Branch**: `improvement-#010-security-scanning`  ·  **Spec dir**: `specs/010-security-scanning/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `cypherid-web-infra` (base: `improvement-#002-tofu-conversion`)

**Input**: Add the security gates to the web-infra deploy repo. It is large (100+ stacks) and long-lived, so — like `cypherid-workflow-infra` — the misconfig/lint scanners run in **report mode** (surface, ratchet) while secret scanning **hard-fails**.

## Posture — `.github/workflows/security.yml`

| Job | Tool | Mode |
|---|---|---|
| `gitleaks` | gitleaks (MIT CLI) | **HARD-FAIL** (FPs triaged in `.gitleaks.toml`) |
| `trivy` | Trivy `fs` (vuln+misconfig+secret, HIGH/CRITICAL) | **REPORT** (`exit-code: 0`); ratchet later |
| `tflint` | tflint `--recursive` | **REPORT** (`continue-on-error`) across the many stacks |
| `checkov` | Checkov (terraform) | **OPT-IN** (`run_checkov`), report-only |

## Secret-scan triage — `.gitleaks.toml`

gitleaks reported **6 leaks**, all `hashicorp-tf-password` in `terraform/envs/{dev,staging}/auth0/main.tf`. **Triaged → all false positives:** the rule matched the literal token `"password"` in the auth0 OAuth **grant-type** lists (`"password"`, `"password-realm"` — partly in *commented-out* lines) and the `password_policy` connection-policy config. These are auth0 configuration, not credentials; real auth0 secrets come from the provider config / variables. Allowlisted by path (`terraform/envs/*/auth0/main.tf`). **Verified:** gitleaks exits 0 after the allowlist.

## Trivy backlog

The gauge scan surfaced an extensive set of HIGH/CRITICAL IaC findings across the 100+ stacks (same families as `cypherid-workflow-infra`: unrestricted SG egress, missing S3 public-access-blocks, unencrypted SNS/SQS/buckets, IMDSv2, mutable ECR tags, …). Far too many to block on day one; surfaced in report mode and triaged down over time (overlaps the broader prod-hardening work). Some of these intersect the spawned EKS public-endpoint finding (task to restrict `public_access_cidrs`).

## Verification

- gitleaks: exit 0 after the allowlist (6 FPs suppressed).
- `security.yml` valid workflow YAML (4 jobs).
- Renovate (improvement-#009) keeps the pinned action/tool versions current.
