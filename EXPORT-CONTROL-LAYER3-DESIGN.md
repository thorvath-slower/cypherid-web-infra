# Layer 3 — identity verification + device/location attestation (CZID-328 / CZID-329)

Design + feasibility spike for the third enforcement layer: true-origin assurance where the **network layer
structurally cannot** reach (residential proxies, location spoofing). Layers 1–2 deny the *network* evasion
channels; Layer 3 answers "is this verified person actually entitled, and actually where they claim?"

> **Heavily counsel/vendor-gated.** Engineering designs the *mechanism* (a fail-closed, provider-agnostic gate);
> the **data classification, the screening lists + hit-handling, the IDV/device vendors + their DPAs, consent,
> and the precise-location privacy questions are counsel's** (design doc §10 items 2,3,6,7). Nothing here ships
> on engineering's say-so. This is the spike that tees those decisions up.

---

## Why Layer 3 is mandatory (not optional)

A residential proxy looks like a real home in an allowed country; GPS/location can be spoofed. No purely-network
control can see the true physical origin behind those. For a **zero-tolerance** posture, the only closure is to
(a) require a **verified identity** that is export-screened, and (b) for the strongest cases, **attest the
device's real location**. A stolen/borrowed allowed-country identity is the residual risk (IR + periodic review,
CZID-334) — Layer 3 shrinks the gap to that residual, which is the defensible standard.

---

## CZID-328 — identity verification + export screening

**Where it runs:** the auth layer (Auth0) as a **post-login Action**, gating access to export-controlled
data/functions. App/auth, not IaC.

**Flow (fail-closed):**
1. **Scope check** — is this login touching export-controlled data/functions? *(The data classification —
   what's controlled, deemed-export scope — is **counsel's**, CZID-322/328. The Action keys off a
   classification flag/role; it does not decide the classification.)* Not in scope → no extra gate.
2. **Verified identity required** — controlled access requires a **verified** identity/affiliation: institutional
   SSO/affiliation, or an IDV vendor claim. *(The acceptable verification method is gated — CZID-328.)*
   Unverified → deny.
3. **Export screening** — screen the identity against denied/restricted-party lists (OFAC SDN, BIS Entity List,
   …). *(The applicable lists, the screening vendor, and the legally-correct response to a hit are **counsel's** —
   CZID-328.)* The call is **provider-agnostic** (a screening adapter, mirroring the Layer-2 IP-intel adapter).
   **Fail-closed:** screening error/timeout → deny.
4. **Decision + audit** — allow / deny / step-up; every decision logged to the export-control evidence trail
   (CZID-331), same record shape as the edge decisions.

**Scaffold:** `auth0/export-control-access-gate/` — a working, fail-closed post-login Action + a screening
adapter contract, with the vendor + lists as injected config/secrets (placeholders). See its README.

---

## CZID-329 — device / location attestation (FEASIBILITY SPIKE)

**Question:** can a **web app** get legally-defensible *device-level* location to defeat residential-proxy /
GPS spoofing — or does it require a client component?

| Option | What it is | Anti-spoof / legal-grade | Web-app fit | Verdict |
|---|---|---|---|---|
| **Browser Geolocation API** (`navigator.geolocation`) | GPS/Wi-Fi via the browser, with user permission | **Weak** — spoofable (devtools, fake-GPS), permission-gated, often IP-derived | Easy, no SDK | **Defense-in-depth only**, not the legal control |
| **Specialist client SDK** (e.g. **GeoComply PinPoint**) | a vendor SDK doing anti-spoof device geolocation | **Strong** — the standard for legally-mandated geofencing (iGaming/streaming) | Requires embedding a vendor SDK (web SDK or app); UX + consent | **The legal-grade path** — but a product + vendor + DPA decision |
| **WebAuthn / device binding** | cryptographic device identity | N/A — proves *device*, not *location* | Good | Complements identity (328), does **not** solve location |

**Finding:** a pure web app **cannot** produce legally-defensible device location with the browser API alone —
it's spoofable. Legal-grade device-location requires a **specialist client SDK** (GeoComply the leading
candidate, consistent with the Layer-2 provider eval), which is a **product/UX + vendor + DPA** decision, not
just engineering. Precise location is **sensitive PII** → consent + DPA + possible location/biometric statutes
(counsel, CZID-329 §10 item 7).

**Recommended sequencing:**
1. **Do CZID-328 first** — identity + export screening is tractable in the web app now (Auth0 Action + a
   screening adapter) and delivers most of the Layer-3 value (a verified, screened identity is a strong
   true-origin signal).
2. **CZID-329 as a gated spike** — evaluate GeoComply PinPoint (web SDK) as the device-location vendor, scoped to
   only the **highest-sensitivity** controlled functions (minimize the precise-location collection surface).
   Use the browser API only as a non-authoritative defense-in-depth signal.

---

## The boundary (who owns what)

- **Counsel:** data classification + deemed-export scope; the screening lists + hit-handling; the IDV and
  device-location **vendors + DPAs**; consent + precise-location privacy; the go-live certification (CZID-335).
- **Engineering:** the fail-closed, provider-agnostic Action + screening adapter (328); the device-location
  feasibility + integration once a vendor is chosen (329); audit logging to the CZID-331 store.
- **Product:** whether to embed a device-location SDK, and on which flows.

## Status

- CZID-328 — Action scaffold + screening-adapter contract authored (fail-closed, provider-agnostic). Vendor +
  lists + classification gated.
- CZID-329 — feasibility spike documented (above). Vendor PoC (GeoComply) + DPA gated.
