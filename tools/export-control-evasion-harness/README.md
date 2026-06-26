# Export-control evasion test harness — CZID-333

The **pre-go-live gate** (and ongoing regression) for the geo/VPN enforcement (epic CZID-321). It attempts to
reach a deployed endpoint via every evasion vector in the design-doc threat model and asserts the enforcement
**denies** each one — and that a clean allowed request is **not** denied.

> No applied infrastructure required to author/run the harness; it probes whatever `TARGET_URL` you give it.
> Run it against **dev with the controls enabled** as the gate before promoting, and on a schedule after.

## Run

```bash
TARGET_URL=https://dev.<app-domain> python3 run.py
# with evasion infrastructure wired in:
TARGET_URL=https://dev.<app-domain> \
  PROXY_VPN=http://user:pass@vpn-exit:8080 \
  PROXY_RESIDENTIAL=http://user:pass@resi-proxy:8000 \
  TOR_PROXY=socks5h://127.0.0.1:9050 \
  python3 run.py
```

No third-party packages required (stdlib only). SOCKS/Tor needs `pip install PySocks`.

## Vectors (design-doc §3 threat model)

| Vector | Layer it must be caught by | How the harness drives it |
|---|---|---|
| Direct from blocked country | L1 geo (CZID-323) | spoofed viewer-country header *(app-layer / defense-in-depth only — see note)* |
| Commercial VPN / datacenter | L1 AnonymousIpList (324) + L2 | `PROXY_VPN` |
| Open / public proxy | L1 + L2 | `PROXY_OPEN` |
| Tor exit | L1 (Tor exits) + L2 | `TOR_PROXY` |
| Cloud / hosting-relayed | L1 HostingProviderIPList + L2 | `PROXY_HOSTING` |
| **Residential proxy** | **L2 IP-intel (327)** | `PROXY_RESIDENTIAL` *(the core Layer-2 test)* |
| Clean allowed request | (false-positive check) | direct, no proxy |

## Honest limits (and the manual procedure)

- **Edge geo can't be header-spoofed** — CloudFront overwrites `CloudFront-Viewer-Country`, so the
  `direct_blocked_country` vector here only exercises *app-layer* geo. The **true** edge geo test requires an
  exit node physically in a blocked jurisdiction — run the harness from a **blocked-country VPN endpoint** and
  point `TARGET_URL` at the edge. That run is manual/credentialed.
- **Residential proxies** need a paid, credentialed residential-proxy service — that's the structural gap Layer 2
  (and Layer 3) exist to close, so this vector is the most important one to actually wire up before go-live.
- A vector with no endpoint configured is **SKIPPED** (not passed). The gate is only fully closed when every
  expected-deny vector has been *run* and denied.

## Output & exit code

- Writes timestamped evidence JSON to `EVIDENCE_DIR` (default `./evidence`) — retain it as part of the CZID-331
  compliance trail.
- **Exit 0** only if every *runnable* expected-deny vector was denied and the clean request was allowed.
- **Non-zero** if any expected-deny vector got through (or the clean request was denied) — **do not promote.**
  Wire this exit code into the promotion gate before any prod enable (CZID-335 sign-off still required).
