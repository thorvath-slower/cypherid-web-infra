# Export-Control Geofencing — Bucket-B Outline (what is NOT done in this branch)

**Branch:** `czid-321-export-control-terraform` (epic CZID-321). **Status:** IaC authored + `fmt`-clean;
**nothing applied.** This file lists everything that requires **bucket-b** action — an AWS apply and/or a
counsel/compliance determination — i.e. the steps that need Tom's explicit go-ahead or a legal sign-off.

> Hard rule: all AWS work is bucket-b. Nothing in this branch is applied without Tom's express per-step OK,
> canary-first, dev → staging → prod, gated on the CZID-333 evasion harness + counsel sign-off (CZID-335).

---

## A. What IS done here (engineering, locally — review only)
| Ticket | Change | File |
|---|---|---|
| CZID-323 | geo-block list → `CU,IR,KP,RU,SY,UA` | `modules/waf-georestriction-main/main.tf` |
| CZID-324 | `AWSManagedRulesAnonymousIpList` rule (block VPN/proxy/Tor/hosting) | `modules/web-acl-regional-v3.3.1/main.tf` |
| CZID-325 | `AWSManagedRulesAmazonIpReputationList` + rate-limit count→block | same |
| CZID-331 | immutable audit-log store — Object Lock (COMPLIANCE) bucket + versioning + TLS-only/WAF-log policy + optional edge-log Firehose; `tofu validate` clean | `modules/export-control-audit-log/` (+ `…/logging.tf` spec) |
| CZID-327 | Layer-2 CloudFront + Lambda@Edge **scaffold** (provider-agnostic) | `modules/edge-ip-intel/` |
| CZID-332 | monitoring + alerting (alarms, SNS, dashboard) — authored, `tofu validate` clean | `modules/export-control-monitoring/` |
| CZID-333 | evasion test harness (pre-go-live gate), self-test passing | `tools/export-control-evasion-harness/` |
| CZID-334 | IR runbook + periodic-review cadence | `EXPORT-CONTROL-IR-RUNBOOK.md` |

All Layer-1/2 enforcement is gated behind `count_only` (canary) / `DRY_RUN` (Lambda log-only).

## B. Bucket-B — AWS apply steps (need Tom's go-ahead, canary-first)
1. **Layer 1 WAF (323/324/325):** `tofu fmt && validate && plan` per env → apply to **dev with `count_only = true`**
   → watch CloudWatch (esp. `HostingProviderIPList` catching legit cloud/CI clients, and the all-`UA`/all-`RU`
   over-block) → add allowlist for known-good corporate/CI egress → flip `count_only = false` → staging → prod.
2. **Layer 2 edge (327):** build the Lambda artifact (`<1 MB`); put the provider API key in **Secrets Manager
   (us-east-1)**; create the **us-east-1 ACM cert**; `apply` the CloudFront distribution + published Lambda@Edge
   with `DRY_RUN` log-only → measure would-be blocks/false-positives on real traffic → tune `RISK_THRESHOLD` →
   flip `DRY_RUN=false` → dev → staging → prod. Re-point app DNS to CloudFront only after validation.
3. **CZID-331 evidence store (SEPARATE store, not a migration):** stand up the dedicated Object Lock
   (COMPLIANCE) store (`modules/export-control-audit-log`) for export-control EVIDENCE only — kept **separate**
   from the normal WAF/app log bucket (separation of concerns: don't conflate operational logs into the
   compliance regime). Wire the **edge Lambda decisions** to it (per-region CloudWatch subscription → its
   Firehose); the normal WAF log bucket stays as-is at operational retention. Optionally also route the
   geo/anonymizer WAF *blocks* to it if counsel wants those immutable. Set the controlled store's
   `retention_days` to the counsel-confirmed record-keeping period (COMPLIANCE can't be shortened later).
4. **Env wiring:** pass `count_only = true` in `envs/{dev,staging,sandbox,prod}/web-waf/main.tf` for the canary,
   then remove to enforce.
5. **CloudFront coordination:** fronting the app affects caching/headers/cost beyond security — land **one**
   CloudFront layer in step with the ALB/EKS modernization, not two.

## C. Bucket-B — counsel / compliance (NOT engineering; gates go-live)
| Item | Ticket | Why it's counsel's |
|---|---|---|
| Authoritative blocked-jurisdiction list (**ratify `RU`**; deemed-export scope) | CZID-322 | OFAC/EAR legal call; RU is program-specific, not a comprehensive embargo |
| Denied/restricted-party screening lists + hit-handling | CZID-328 | the lists + the legally-correct response to a hit are defined by law |
| IP-intel provider **DPA** + data residency (we send IPs) | CZID-326/335 | privacy law (GDPR/CCPA), data-sharing review |
| Identity/IDV + device-location vendor **DPAs** + consent | CZID-328/329/335 | sensitive PII + precise-location statutes |
| Export-control **attestation / ToU** wording + 403 messaging | CZID-330 | legal text with enforceability weight |
| Audit-log content + **retention period** | CZID-331 | export record-keeping (~5yr) vs privacy caps — counsel balances |
| Residual-risk acceptance + **go-live certification** | CZID-335 | only counsel can certify the controls meet the obligation |

## D. Out of scope for Terraform (tracked, not here)
- **CZID-326** provider decision — RFP/PoC **GeoComply** (legal-grade, Layer 2+3) vs **Spur** (Layer-2 only) +
  MaxMind/IPinfo baseline. The Lambda adapter swaps with one constant once chosen.
- **Layer 3 (CZID-328/329)** — identity verification + export screening via **Auth0 post-login Actions**, and a
  **device-location feasibility spike** (web-app vs client SDK). App/auth layer, not IaC.
- **CZID-332** monitoring, **CZID-333** evasion harness, **CZID-334** IR runbook — **now authored** (see §A).
  Remaining to fully close: the harness needs credentialed proxy/VPN/residential endpoints + a blocked-country
  exit node to exercise every vector; monitoring + IR need the apply + compliance-owned alert recipients and the
  counsel-defined retention period.
