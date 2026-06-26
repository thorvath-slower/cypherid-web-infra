# Export-control enforcement — incident response runbook + periodic review (CZID-334)

Operational runbook for a suspected **blocked-jurisdiction access or enforcement bypass**, plus the recurring
control-effectiveness review. Part of epic **CZID-321**.

> **Boundary:** engineering **detects, contains, and preserves evidence**. **Counsel / the export-control office
> own the legal determination and any external reporting** — a confirmed or suspected sanctioned-party access may
> carry notification obligations. **Escalate to them early; do not make the legal call in this runbook.**

---

## 1. Detection — how an incident surfaces

| Source | Signal | Ticket |
|---|---|---|
| CloudWatch alarm | `…-blocked-jurisdiction-attempts` (geo) — sustained direct attempts | CZID-332/323 |
| CloudWatch alarm | `…-anonymizer-hits` spike — evasion surge | CZID-332/324 |
| CloudWatch alarm | `…-fail-closed-denials` — Layer-2 provider degraded (denying legit users) | CZID-332/330 |
| CloudWatch alarm | `…-waf-blocked-spike` — broad anomaly | CZID-332 |
| Evasion harness | a regression run reports a vector **got through** | CZID-333 |
| Manual report | a user/partner reports unexpected access or an over-block | — |

All alarms page the `export-control-<env>-alerts` SNS topic (on-call + compliance).

## 2. Triage (first 15 minutes)

1. **Classify the signal:**
   - *Enforcement working* (denies climbing) → a blocked-origin actor is being stopped. Investigate scope; this is
     evidence the control works, but a **sustained, targeted** pattern may still be reportable — loop in compliance.
   - *Possible bypass* (harness vector got through, or an allowed request from a suspected blocked origin) →
     **treat as a control failure. Highest priority.**
   - *Fail-closed storm* (`fail-closed-denials` high) → the IP-intel provider is degraded; we are correctly denying
     but also denying legitimate users — an **availability** incident, not a breach. Engage the provider / failover.
2. **Severity:** a *confirmed bypass of a sanctioned jurisdiction* is **Sev-1** and an immediate compliance
   escalation. Over-block / availability issues are Sev-2/3.
3. **Page compliance/counsel now** for any suspected real bypass or a sustained targeted access pattern.

## 3. Containment

- **Confirmed bypass:** tighten immediately and reversibly —
  - flip the relevant WAF rule out of any `count_only` canary to enforce (`count_only = false`);
  - if Layer 2 is the gap, set the edge Lambda to fail-closed-always / lower `RISK_THRESHOLD` and redeploy;
  - if a specific allowlisted range is the hole, remove it.
- **Never widen access during an incident.** Zero-tolerance: when unsure, deny.
- Record every change (what/when/who) — it becomes part of the evidence.

## 4. Investigation — reconstruct from the audit trail (CZID-331)

The immutable audit log records every decision (timestamp, IP, geo verdict, VPN/proxy verdict, identity,
allow/deny + reason). Pull the relevant window and answer:

- What was the **origin** (IP, ASN, viewer-country) and which **vector** (geo / anonymizer / residential / clean)?
- Which **layer** should have caught it, and **why didn't it** (rule in count-mode? provider miss? allowlist hole?
  residential proxy = known Layer-2 gap → Layer-3 territory)?
- **Scope:** one actor or many? What was accessed (export-controlled data/functions)?
- Preserve the relevant WAF logs, Lambda logs, and audit records to immutable storage before they age out.

## 5. Notification & remediation

- **Compliance/counsel decide** any external notification/reporting — provide them the timeline + evidence.
- Engineering remediation: close the specific gap (rule tuning, provider escalation, allowlist fix, or a Layer-3
  follow-up for residential/identity gaps), then **re-run the evasion harness (CZID-333)** to confirm the vector
  is now denied. Add a regression case for the specific bypass.

## 6. Evidence retention

Preserve the incident timeline, the audit-log extract, alarm history, and harness evidence to the immutable store
for the **record-keeping retention period (counsel-defined — CZID-331)**. This is the compliance trail proving the
control operated and the incident was handled.

---

## 7. Periodic review (recurring, not incident-driven)

| Cadence | Activity | Ticket |
|---|---|---|
| **Quarterly** | Control-effectiveness review: alarm/incident trends, false-positive rate, allowlist audit | CZID-334 |
| **Quarterly / on-change** | Re-run the full evasion harness (incl. credentialed residential + blocked-country vectors) as a regression; retain evidence | CZID-333 |
| **On list change** | When counsel updates the blocked-jurisdiction list (CZID-322), update the config var, re-plan, canary, and re-test — never hard-code | CZID-322/323 |
| **On provider/threshold change** | Re-validate Layer-2 risk thresholds + false-positive impact after any IP-intel provider or tuning change | CZID-326/327 |
| **Annually / pre-audit** | Confirm retention, immutability, and the go-live certification are still current | CZID-331/335 |

> The review cadence ties directly to CZID-322 (list governance) and CZID-335 (sign-off): controls drift, lists
> change, and providers regress — periodic re-validation is part of the "reasonable measures" standard, not optional.
