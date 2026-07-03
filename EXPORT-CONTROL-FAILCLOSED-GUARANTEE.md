# Export-control fail-closed guarantee — per-surface (CZID-330)

The zero-tolerance mandate (epic CZID-321, design doc §6) requires that **every** enforcement surface
default to **DENY on error, timeout, or ambiguity** — there is no "allow on uncertainty" path. This doc
is the authoritative record of *how* each surface meets that guarantee, what was verified, and which
decisions are **counsel-owned** (flagged `TODO(counsel)` in code and listed at the bottom).

> Nothing here is applied to AWS. IaC + Lambda are authored/validated locally; every apply is bucket-b
> and go-live is gated on counsel sign-off (CZID-335).

---

## Surface 1 — Layer-2 edge Lambda@Edge (`modules/edge-ip-intel/lambda`)

The viewer-request handler is the first surface every request hits. It is fail-closed at **five** points:

| Vector | Behavior | Where |
|---|---|---|
| CloudFront could not resolve the viewer country | **DENY** `ambiguous_no_country` | `index.mjs` guard 0 |
| No usable client IP (empty / `-` / `unknown` sentinel) | **DENY** `ambiguous_no_ip` | `index.mjs` guard 0 + `isUsableIp()` |
| Viewer country in the blocked set | **DENY** `geo` (short-circuit, no provider call) | `isBlockedCountry()` |
| Provider error **or** timeout (AbortController → throw) | **DENY** `provider_error` | `try/catch` around `classify()` |
| Provider returned a malformed / partial verdict | **DENY** `ambiguous_verdict` | `isWellFormedVerdict()` |
| VPN / proxy / Tor / hosting / residential-proxy / risk ≥ threshold | **DENY** `anonymizer_or_risk` | verdict evaluation |
| **Only** a clean, well-formed verdict for a known non-blocked country | **ALLOW** (forward to origin) | terminal `allow` |

**Hardening added by CZID-330** (the scaffold was already fail-closed on provider error; these close the
residual *ambiguity* gaps that could previously coerce to allow):
- **Missing viewer country → DENY.** Previously fell through to the provider; an unknown origin is
  exactly the uncertainty the mandate forbids allowing.
- **Empty / sentinel IP → DENY.** Without an IP the IP-intel layer cannot screen for VPN/proxy; a 200
  from the provider on an empty IP could otherwise read as "clean".
- **Verdict-shape guard → DENY.** A partial response (missing `riskScore`, non-boolean flags) would let
  silently-falsy fields coerce `bad` to `false` and slip through. Now every flag must be a real boolean
  and `riskScore` a finite number, or the request is denied as ambiguous.

**Verified:** `terraform/modules/edge-ip-intel/lambda/test/failclosed.test.mjs` — 11 stdlib-only unit
tests (no network/creds) exercising every vector above. Run: `node --test test/failclosed.test.mjs`
from the lambda dir. All pass; the single ALLOW test proves allow is reachable *only* on a clean verdict.

**`DRY_RUN` caveat (fail-OPEN by design):** `DRY_RUN = true` logs the would-be decision but always
forwards — a tuning canary only. It is `false` in source and **MUST** be `false` at go-live. The evasion
harness (CZID-333) and the go-live checklist verify `DRY_RUN === false` as a gate.

---

## Surface 2 — Layer-1 regional WAF geo-block (`modules/waf-georestriction-main`)

The geo-block rule group action is unconditionally `block {}` for any request whose country is in the
list. Fail-closed properties:
- **No default for `blocked_country_codes`** — wiring from the SSOT JSON is required, so the list can
  never be silently absent.
- **Non-empty validation (added, CZID-330)** — a `validation {}` block fails the plan if the list is
  empty (which would make the geo rule a no-op / fail-open) or if any code is not a well-formed ISO
  alpha-2. The only correct way to change the geo layer is a deliberate, reviewed edit to the
  counsel-owned SSOT JSON — never an empty file.

---

## Surface 3 — Layer-1 WAF WebACL default action (`modules/web-acl-regional-v3.3.1`)

⚠️ **DECISION POINT (architecture) — the WebACL `default_action` is `allow {}`.**

This is the standard CZI shared-infra **block-list** model: the WAF explicitly blocks bad traffic
(geo-block rule group, AnonymousIpList, IP-reputation, rate-limit, managed rule sets) and allows the
rest. For export control, the *deny-by-default* guarantee is delivered by the **layers in front and
within** (the edge Lambda denies on any ambiguity; the geo + anonymizer rules block the sanctioned/
evasion traffic), **not** by flipping this WebACL to `default_action = block {}`.

- **Why not flip it to `block`:** this module is a **vendored CZI baseline** consumed across the fleet;
  a deny-by-default WebACL would require an explicit allow-list of every legitimate request pattern and
  would break every consumer. That is out of scope for CZID-330 and is not how a WAF block-list is meant
  to operate. Per repo doctrine (never modify vendored-module internals casually; SSOT), the default
  action is left as-is and the fail-closed guarantee is carried by Surfaces 1 & 2.
- **`count_only` canary:** every CZI-managed rule (and the AnonymousIpList sub-rules) can be put in
  COUNT mode for tuning. `count_only` **defaults to `false` (blocking)** and `anonymous_ip_count_rules`
  **defaults to `[]` (block all)** — i.e. fail-closed by default. While any rule is in COUNT it is
  fail-OPEN for that vector; COUNT is a pre-go-live tuning state and the go-live gate requires all
  export-control rules in BLOCK. **`TODO(counsel)/ops:** confirm no export-control rule is left in
  COUNT at go-live.

---

## Surface 4 — CloudFront (`modules/edge-ip-intel/main.tf`)

- The distribution's own `geo_restriction.restriction_type = "none"` **by design** — geo is enforced at
  the WAF (Layer 1) and the edge Lambda (Layer 2), not duplicated in the CloudFront geo restriction.
  This is not a fail-open: the Lambda runs on `viewer-request` before the cache and denies ambiguity.
- The Lambda is associated on `viewer-request` (before cache) with the **version-qualified** ARN, so
  every viewer request is screened. `include_body = false` (not needed for the IP/geo decision).
- **Residual (documented, not a code gap):** CloudFront does not natively "fail closed" if the Lambda
  association itself fails to invoke (an AWS-platform error). This is an operational/monitoring concern —
  CZID-332 alarms on Layer-2 fail-closed denials + invocation errors; the IR runbook (CZID-334) covers a
  suspected bypass. Flagged for ops sign-off at go-live.

---

## Counsel / decision points flagged (not decided here)

1. **Denial / attestation user-facing wording** — `TODO(counsel)` in `index.mjs` `decide()` (the 403
   body) and in the app attestation UI (Part B). Legal text has enforceability weight; counsel owns it.
2. **WebACL `default_action = allow`** (Surface 3) — engineering recommends leaving it as the standard
   block-list default and carrying deny-by-default via Surfaces 1–2. **Confirm this posture is acceptable
   for the export-control residual-risk acceptance (CZID-335).**
3. **`count_only` / `DRY_RUN` at go-live** — ops/counsel gate: verify no export-control rule is left in
   COUNT and `DRY_RUN === false` before enable.
4. **Blocked-jurisdiction list content** remains counsel-owned (CZID-322); this doc only guards *shape*
   and *non-emptiness*, never the content.
