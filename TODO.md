# TODO — cypherid-web-infra

Outstanding work for this repo: fixes, upgrades, security findings, and
half-baked items. Forward-looking companion to the program-level
`SESSION-ACCOMPLISHMENTS` (done work) and the jslower security review (audit).

**Refs** in `[brackets]` cross-reference: the review IDs (`IAM-1`…), our
`bug-`/`improvement-` branches, and the security findings register.
**Status:** OPEN · PARTIAL · BLOCKED. **Priority:** P0 blocking · P1 high · P2 med · P3 cleanup.

## Security & IAM
- [ ] **[IAM-1 / CICD-1, bug-#007] (P0) Replace PowerUserAccess with least-privilege.**
  `bug-#007` *removed* the managed PowerUserAccess from dev/staging deploy roles; the
  remaining work is to attach an explicit minimal customer-managed policy, split
  read-only *plan* vs write *apply* roles, scope the OIDC trust policy (refs, not
  `:pull_request`), and stop exporting creds. Apply with a bootstrap admin profile.
  → **see [`docs/IAM-DEPLOY-ROLES.md`](docs/IAM-DEPLOY-ROLES.md).**
- [ ] [SEC-1] (P2) Services private key persists in TF state; adopt `ephemeral "tls_private_key"`, feed `secret_string_wo`, set `recovery_window_in_days` to 7–30 for non-dev. `modules/czid-services-private-key/main.tf`.
- [ ] [security-scan, improvement-#010] (P2) **591 Checkov findings** in report mode — triage + ratchet the gate to hard-fail. Top families: S3 (public-access-block, KMS, logging, versioning, CRR), IAM `*`/write, CloudFront (WAF/TLS/logging), module commit-hash pinning. → `docs/SECURITY-FINDINGS-DETAILED.md` (czid-infra) + the register xlsx.
- [x] [bug-#012] Digest-pin grafana + python:3.7 bases; fix the unverified chamber checksum. *(done, branch bug-#012-unproxied-dependencies)*

## CI/CD
- [ ] [CICD-1] (P0) OIDC trust-policy scoping + split plan/apply roles — paired with IAM-1 above.
- [ ] [CICD-5] (P3) Remove the `Print GitHub context` debug step (`plan_all.yml`).
- [ ] [CICD-6] (P2) Replace hardcoded account/role ARNs (`941377154785`) with `vars.*`.
- [x] [improvement-#002] Converted off fogg/Terraform-Cloud to OpenTofu; added `tofu_ci.yml`. *(done)*
- [x] [improvement-#009] Renovate config (terraform providers grouped, digests, actions). *(done)*

## Data / infra
- [ ] [DATA-1] (P1) Env-gate destructive flags: `force_destroy = var.env == "dev"`, `prevent_destroy = true` on prod/staging data buckets. `db/bucket.tf`.
- [ ] [DATA-2/3, NET-1] (P1/P2) RDS resilience (deletion protection, backups, monitoring), stop `general_log=1`, keep RDS private. **NOTE:** the program is migrating to **PostgreSQL** (`improvement-#005`, seqtoid-web) — re-scope these MySQL/Aurora items to the Postgres target before acting.
- [ ] [bug-#014] (P2) Provider-resolution fixes for prod/acm-validation + prod/s3-tf-state. *(done on branch bug-#014-provider-resolution — pending merge)*

## Runtime & dependencies
- [ ] [EOL-2] (P2) grafana 7.1.2 / python:3.7-slim bases are EOL — pinned (`bug-#012`) but not upgraded. Bump when feasible (Renovate will surface).

## Known issues needing input
- [ ] Broken components (prod/redis, prod/email, prod/maintenance, prod/zendesk, sandbox/db): original prod values not recoverable from the repos — recover or confirm-dead-and-remove (needs Tom). → `docs/KNOWN-ISSUES.md`.

## Done this session, awaiting merge/push (branches, nothing pushed)
- `improvement-#002-tofu-conversion` (base) · `improvement-#009-renovate` · `improvement-#010-security-scanning` · `bug-#012-unproxied-dependencies` · `bug-#014-provider-resolution` · `feature-#002-blue-green-delivery`
