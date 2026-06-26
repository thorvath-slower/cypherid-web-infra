# Export-control enforcement — implementation status & how it works

The single entry point for the export-control geo/VPN enforcement program (epic **CZID-321**). It explains how
the pieces fit, what each does, and exactly what's left and who owns it. Deep-dives live in the linked docs.

> **Nothing here is applied to AWS.** All IaC is authored + validated locally on
> `czid-321-export-control-terraform` (pushed to the fork, **no PR, no merge**). Every apply is bucket-b
> (Tom's explicit go), and go-live is gated on counsel sign-off (CZID-335).

**Doc map:** design & threat model → `EXPORT-CONTROL-GEO-VPN-ENFORCEMENT-2026-06-25.md` · apply steps + gated
items → `EXPORT-CONTROL-BUCKET-B-OUTLINE.md` · list governance → `EXPORT-CONTROL-LIST-GOVERNANCE.md` ·
provider choice → `EXPORT-CONTROL-IP-INTEL-PROVIDER-EVAL.md` · incident response → `EXPORT-CONTROL-IR-RUNBOOK.md`.

---

## The mandate, in one paragraph

US export controls, **zero-tolerance**: no access from sanctioned jurisdictions, **and** no access via
VPN/proxy/anonymizer regardless of the location it claims. Because IP-geolocation can't see the true country
behind a well-run VPN/residential proxy, a geofence alone can't meet this — so enforcement is **three layers**:
geofence direct traffic, deny the evasion channel (VPN/proxy/Tor), and verify identity/device where the network
layer structurally can't. **Fail-closed everywhere; fully audited; tested; legally signed off.**

---

## How it works (request flow)

```
Client ─▶ CloudFront ─▶ Lambda@Edge (Layer 2, viewer-request)         [edge-ip-intel module]
                          • geo short-circuit (blocked country → 403)
                          • IP-intel provider: VPN/proxy/residential risk
                          • FAIL-CLOSED: any error/timeout → 403
                        ─▶ ALB ─▶ AWS WAF Web ACL (Layer 1)            [web-acl + georestriction modules]
                          • geo-match block (sanctioned list)
                          • AnonymousIpList (VPN/proxy/Tor/hosting)
                          • IP-reputation + rate-limit
                        ─▶ app ─▶ Auth0 (Layer 3: identity + device)  [not built — app/auth work]
                          ─▶ export-controlled data
```

The **blocked-jurisdiction list is one file** both Layer 1 and Layer 2 read, so they can't drift. A request from
a blocked origin is caught at every path: direct → geofence; via VPN → anonymizer block + IP-intel; via
residential proxy → IP-intel + (Layer 3) identity/device.

---

## Status at a glance

| Ticket | Piece | Where | Status |
|---|---|---|---|
| CZID-323 | Layer-1 geo-block | `modules/waf-georestriction-main` | ✅ authored (canary `count_only`) |
| CZID-324 | Layer-1 AnonymousIpList | `modules/web-acl-regional-v3.3.1` | ✅ authored |
| CZID-325 | Layer-1 IP-reputation + rate-limit | same | ✅ authored |
| CZID-327 | Layer-2 CloudFront + Lambda@Edge | `modules/edge-ip-intel` | ✅ scaffold (provider-agnostic, `DRY_RUN`) |
| CZID-326 | Layer-2 provider selection | `EXPORT-CONTROL-IP-INTEL-PROVIDER-EVAL.md` | ✅ eval done — **selection = counsel/procurement** |
| CZID-322 | Blocked-jurisdiction list + governance | `export-control/blocked-jurisdictions.json`, `tools/validate-…py`, `…-LIST-GOVERNANCE.md` | ✅ mechanism — **content = counsel** |
| CZID-330 | Fail-closed enforcement | Lambda + WAF | ✅ done (verified) |
| CZID-331 | Immutable audit log | `modules/export-control-audit-log` | ✅ IaC authored (Object Lock COMPLIANCE) — apply = destructive migration (bucket-b) |
| CZID-332 | Monitoring + alerting | `modules/export-control-monitoring` | ✅ authored (`tofu validate`) |
| CZID-333 | Evasion test harness | `tools/export-control-evasion-harness` | ✅ built (self-test) — needs credentialed endpoints to fully close |
| CZID-334 | IR runbook + review cadence | `EXPORT-CONTROL-IR-RUNBOOK.md` | ✅ done |
| CZID-328/329 | Layer-3 identity + device | — | ⛔ not started (app/auth + device spike) |
| CZID-335 | Docs + go-live sign-off | this + linked docs | 🔲 **counsel certifies** |

---

## How each part works

- **The single source (CZID-322).** `export-control/blocked-jurisdictions.json` holds the `blocked_country_codes`
  (enforced), `rationale` (why each), and `staged_for_counsel` (candidates not yet enforced). The WAF reads it via
  `jsondecode(file(...))` in the dev/staging/prod stacks; the Lambda reads the **same** file, copied into its
  bundle by `lambda/build.sh`. `tools/validate-blocked-jurisdictions.py` is the gate (format, no-dupes, every
  enforced code justified, staged disjoint; optional `pycountry` ISO check). Change procedure: see the governance doc.
- **Layer 1 — WAF (CZID-323/324/325).** A regional WAF on the ALB: a geo-block rule group (the list), AWS
  AnonymousIpList (VPN/proxy/Tor/hosting), IP-reputation, and a rate-limit. All rules run behind `count_only`
  (canary = count, don't block) until tuned, then flip to enforce.
- **Layer 2 — edge IP-intel (CZID-327).** CloudFront + a Lambda@Edge on viewer-request, in front of the WAF/ALB.
  Provider-agnostic: the decision logic uses only the adapter contract, so the provider (CZID-326) is one
  constant. **Fail-closed**: any provider error/timeout → 403. Runs in `DRY_RUN` (log-only) until tuned.
- **Fail-closed (CZID-330).** The Lambda denies on geo, on bad verdict, and on any error; a single `decide()`
  point logs every verdict. The 403 body is a counsel-placeholder.
- **Monitoring (CZID-332).** Alarms on blocked-jurisdiction attempts, anonymizer hits, total blocks, and
  Layer-2 fail-closed denials → an SNS topic + a dashboard. Metric names are sourced from the web-acl module's
  outputs (no re-typed literals).
- **Evasion harness (CZID-333).** Probes a deployed endpoint per threat-model vector and **fails the gate** if
  any expected-deny vector gets through; writes retained evidence. The pre-go-live gate + ongoing regression.
- **IR runbook (CZID-334).** Detection → triage → containment → investigation → counsel escalation →
  remediation → evidence retention, plus the quarterly review cadence.

---

## What still needs to be done

**Engineering (provider-independent):**
- **CZID-331 — audit-log IaC: ✅ authored** (`modules/export-control-audit-log` — Object Lock COMPLIANCE bucket
  + versioning + TLS-only/WAF-log policy + optional edge-log Firehose). Remaining is the bucket-b apply (a
  destructive WAF-log-bucket migration + the per-region edge subscription) and the counsel-set retention period.
- **CZID-328/329 — Layer 3:** identity verification + export screening via Auth0 post-login Actions, and a
  device-location feasibility spike. App/auth work, not IaC; partly gated on vendor/DPA. (Not started.)

**Counsel / compliance (gates go-live — not engineering):**
- The blocked-jurisdiction list **content** + each rationale; ratifying staged entries (CZID-322).
- Data classification / deemed-export scope (CZID-322/328); restricted-party screening + hit-handling (CZID-328).
- DPAs + data-residency for the IP-intel and identity/device vendors (CZID-326/328/329).
- The 403 / attestation / Terms-of-Use **legal text** (CZID-330).
- Audit-log **retention period** (CZID-331).
- Residual-risk acceptance + **go-live certification** (CZID-335).

**Repo admin / ops:**
- Make `validate-blocked-jurisdictions.py` a **required CI check** on the branch.
- The **bucket-b apply** sequence: canary (`count_only`/`DRY_RUN`) → measure on real traffic → tune allowlists +
  thresholds → enforce, dev → staging → prod. See `EXPORT-CONTROL-BUCKET-B-OUTLINE.md`.

---

## The boundary (who owns what)

> **Engineering builds the mechanism; counsel approves the substance.** If an item decides *who is blocked*,
> *what data leaves our boundary*, *what legal text a user sees*, or *what we keep and how long* — it stops and
> routes to counsel. Everything in this branch is the mechanism; none of it decides the substance.
