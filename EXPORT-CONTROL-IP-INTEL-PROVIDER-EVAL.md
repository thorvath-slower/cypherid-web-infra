# Layer-2 IP-intelligence provider — evaluation matrix (CZID-326)

Decision-support for selecting the commercial IP-intelligence provider the Layer-2 edge Lambda (CZID-327)
calls to score each request for VPN / proxy / Tor / hosting / **residential-proxy** risk.

> **This frames the decision; it does not make it.** The selection — and the DPA, data-residency, and
> legal-grade certification it depends on — is **counsel + procurement's** (design doc §10 item 5). The notes
> below reflect each vendor's **public positioning** and must be **verified in a PoC** before any commitment.
>
> **Integration cost is not a differentiator:** the Lambda adapter (`modules/edge-ip-intel/lambda/adapter/`) is
> provider-agnostic, so switching providers is one constant + a small adapter module. Choose on capability,
> legal fit, and cost — not lock-in.

---

## What actually matters here (criteria, weighted to the mandate)

| # | Criterion | Why it matters for export control |
|---|---|---|
| 1 | **Residential-proxy detection** | the structural gap the network layer can't see — the core reason Layer 2 exists |
| 2 | VPN / datacenter / Tor / hosting coverage | the baseline anonymizer denial (AWS AnonymousIpList already covers the *known* set) |
| 3 | **Regulatory / legal-grade pedigree** | a zero-tolerance legal mandate wants a vendor proven in legally-mandated geofencing (iGaming/streaming) |
| 4 | Device-level / Layer-3 capability | defeats GPS/location spoofing the IP layer can't — feeds CZID-329 |
| 5 | **Edge latency / fail-closed fit** | viewer-request budget is tight (5s hard cap); must cache + fail closed cleanly |
| 6 | Cost model + caching | per-query vs feed/DB; can we cache verdicts to control spend |
| 7 | **Data-sharing / DPA / residency** | we send user IPs (PII) — privacy law + a DPA review gate this (counsel) |
| 8 | Accuracy / false-positive profile | over-blocking legitimate users is the operational cost of zero-tolerance |

---

## Candidates (public positioning — verify in PoC)

| Provider | Residential-proxy | Legal-grade | Device-level (L3) | Cost / model | Notes |
|---|---|---|---|---|---|
| **GeoComply** | Strong | **Yes** — the standard for legally-mandated VPN/spoof defeat (iGaming/streaming) | **Yes** (PinPoint, client SDK) | Higher; enterprise contract | Strongest single-vendor fit for a zero-tolerance legal mandate + Layer 3; heavier integration (likely a client component for device-level) |
| **Spur** | **Strong** (specialist in anonymity infra incl. residential) | Partial | No | Mid; API/feed | Excellent Layer-2 residential/anonymizer signal, developer-friendly; no device-level |
| **IPQualityScore** | Good | Partial | No | Low–mid; per-query API | Broad fraud/proxy/VPN detection incl. residential; fraud-oriented, affordable |
| **MaxMind GeoIP2 / minFraud** | Weaker | No (general) | No | Low; DB download or API | Mature baseline geo + Anonymous-IP/minFraud; DPA-mature; residential coverage below specialists |
| **IPinfo (Privacy Detection)** | Improving | No (general) | No | Low; API or DB | Solid geo + VPN/proxy/hosting flags; residential coverage improving, not specialist-grade |

---

## Engineering recommendation (a lean, not the decision)

- **If the legal-grade + device-level (Layer-3, CZID-329) requirement holds** — which a zero-tolerance export
  mandate points to — **GeoComply** is the strongest single-vendor fit, accepting higher cost + integration.
- **If Layer 3 is deferred and cost matters more** — a **two-tier** approach: a cheap baseline DB
  (**MaxMind** or **IPinfo**) for broad coverage, plus a **specialist (Spur or IPQS)** for the
  residential-proxy / high-risk tier. The adapter can combine signals.
- **Avoid** relying on the baseline DBs *alone* — they under-detect residential proxies, the exact gap Layer 2
  must close.

## How to decide (the PoC the selection should run)

1. **RFP / DPA review** (counsel + procurement): data-residency, the IP-data-sharing DPA, legal-grade claims, pricing.
2. **PoC on real traffic** using the Lambda's `DRY_RUN` canary (CZID-327): run the shortlisted providers in
   log-only mode, measure would-be blocks + **false-positive rate** on real allowed-country traffic, and check
   p95 latency against the viewer-request budget.
3. **Tune `RISK_THRESHOLD`** per provider from the PoC data; pick on measured residential-proxy catch rate vs
   false positives vs cost.
4. **Counsel sign-off** on the chosen vendor's DPA before any prod enable (CZID-335).

## What still needs a person

- **Counsel + procurement:** the selection, the DPA / data-residency review, the legal-grade certification.
- **Engineering:** runs the PoC via the existing adapter + `DRY_RUN`, reports the measured numbers, and wires the
  chosen provider (one adapter module).
