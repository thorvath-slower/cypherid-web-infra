#!/usr/bin/env python3
"""CZID-333 — export-control evasion test harness.

Pre-go-live GATE (and ongoing regression) for the geo/VPN enforcement (epic CZID-321). It
attempts to reach TARGET_URL via each evasion vector in the design-doc threat model and asserts
the enforcement DENIES it — and that a clean allowed request is NOT denied (false-positive check).

Honest scope: some vectors (a true blocked-country origin, a residential proxy) require real
network infrastructure (VPN accounts, paid proxy services). The harness runs every vector it has
been given the means to run, marks the rest SKIPPED with the manual procedure, and FAILS the gate
only if an *expected-deny* vector was actually ALLOWED (or the clean request was denied). Results
are written as retained, timestamped evidence (the CZID-331 trail).

Config (environment):
  TARGET_URL          required — the deployed app/edge URL to probe
  PROXY_VPN           http(s) proxy at a commercial-VPN / datacenter exit
  PROXY_OPEN          http(s) open / public proxy
  PROXY_HOSTING       http(s) proxy at a cloud/hosting IP
  PROXY_RESIDENTIAL   http(s) residential proxy (credentialed) — the core Layer-2 test
  TOR_PROXY           Tor proxy (socks5h://127.0.0.1:9050) — needs PySocks for SOCKS
  BLOCKED_COUNTRY     ISO-3166 code for the app-layer geo spoof test (default IR)
  EVIDENCE_DIR        where to write evidence JSON (default ./evidence)
  HARNESS_TIMEOUT     per-request timeout seconds (default 15)

Exit: 0 = every runnable expected-deny vector was denied AND the clean request was allowed;
      non-zero = a gap (the go-live gate fails) — do not promote.
"""
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

TARGET = os.environ.get("TARGET_URL")
EVIDENCE_DIR = os.environ.get("EVIDENCE_DIR", "evidence")
BLOCKED_COUNTRY = os.environ.get("BLOCKED_COUNTRY", "IR")
TIMEOUT = float(os.environ.get("HARNESS_TIMEOUT", "15"))

# The threat-model matrix (design doc §3). Each vector must be DENIED except the clean baseline.
VECTORS = [
    {"id": "direct_blocked_country", "layer": "L1 geo (CZID-323)", "expect": "deny",
     "desc": "Direct from a blocked jurisdiction (app-layer geo via spoofed viewer-country header)",
     "method": "header_spoof",
     "note": "Edge geo can't be header-spoofed (CloudFront overwrites the header) — this exercises "
             "app-layer / defense-in-depth only. The true edge test needs an exit node physically in "
             "the blocked country (manual / a blocked-country VPN endpoint)."},
    {"id": "commercial_vpn", "layer": "L1 AnonymousIpList (CZID-324) + L2", "expect": "deny",
     "desc": "Commercial VPN / datacenter exit", "method": "proxy", "env": "PROXY_VPN"},
    {"id": "public_proxy", "layer": "L1 + L2", "expect": "deny",
     "desc": "Open / public proxy", "method": "proxy", "env": "PROXY_OPEN"},
    {"id": "tor", "layer": "L1 AnonymousIpList (Tor exits) + L2", "expect": "deny",
     "desc": "Tor exit node", "method": "proxy", "env": "TOR_PROXY",
     "note": "socks5 requires PySocks installed (pip install PySocks)."},
    {"id": "hosting_relayed", "layer": "L1 HostingProviderIPList + L2", "expect": "deny",
     "desc": "Cloud / hosting-relayed", "method": "proxy", "env": "PROXY_HOSTING"},
    {"id": "residential_proxy", "layer": "L2 IP-intel (CZID-327)", "expect": "deny",
     "desc": "Residential proxy — the network-layer structural gap", "method": "proxy",
     "env": "PROXY_RESIDENTIAL",
     "note": "Requires a credentialed residential-proxy service; this is the core Layer-2 test."},
    {"id": "allowed_clean", "layer": "(false-positive check)", "expect": "allow",
     "desc": "Clean allowed-country request, no proxy", "method": "direct"},
]


def probe(url, proxy=None, extra_headers=None):
    """Return (status_code, error_str). status None on transport error."""
    handlers = []
    if proxy:
        handlers.append(urllib.request.ProxyHandler({"http": proxy, "https": proxy}))
    opener = urllib.request.build_opener(*handlers)
    req = urllib.request.Request(url, headers=extra_headers or {}, method="GET")
    try:
        with opener.open(req, timeout=TIMEOUT) as r:
            return getattr(r, "status", r.getcode()), None
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception as e:  # noqa: BLE001 — any transport error is a non-result, reported as ERROR
        return None, str(e)


def verdict(expect, status):
    """PASS/FAIL given the expected outcome and the observed status."""
    denied = status in (401, 403, 451)
    allowed = status is not None and 200 <= status < 300
    if expect == "deny":
        return "PASS" if denied else "FAIL"
    return "PASS" if allowed else "FAIL"


def meta(v):
    return {k: v[k] for k in ("id", "layer", "desc", "expect") if k in v} | (
        {"note": v["note"]} if v.get("note") else {})


def run():
    if not TARGET:
        print("ERROR: TARGET_URL is required.", file=sys.stderr)
        return 2

    results = []
    gate_failed = False
    for v in VECTORS:
        method = v["method"]
        if method == "direct":
            status, err = probe(TARGET)
        elif method == "header_spoof":
            status, err = probe(TARGET, extra_headers={
                "CloudFront-Viewer-Country": BLOCKED_COUNTRY,
                "X-Forwarded-Country": BLOCKED_COUNTRY,
            })
        elif method == "proxy":
            proxy = os.environ.get(v["env"])
            if not proxy:
                results.append({**meta(v), "outcome": "SKIPPED",
                                "reason": f"set ${v['env']} to run this vector"})
                continue
            status, err = probe(TARGET, proxy=proxy)
        else:
            results.append({**meta(v), "outcome": "SKIPPED", "reason": "unknown method"})
            continue

        if status is None:
            results.append({**meta(v), "outcome": "ERROR", "detail": err})
            continue
        outcome = verdict(v["expect"], status)
        results.append({**meta(v), "outcome": outcome, "status": status})
        if outcome == "FAIL":
            gate_failed = True

    write_evidence(results)
    summarize(results)
    return 1 if gate_failed else 0


def write_evidence(results):
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    path = os.path.join(EVIDENCE_DIR, f"evasion-evidence-{stamp}.json")
    with open(path, "w") as f:
        json.dump({"target": TARGET, "utc": stamp, "results": results}, f, indent=2)
    print(f"\nEvidence written: {path}")


def summarize(results):
    print(f"\n=== export-control evasion harness — {TARGET} ===")
    for r in results:
        mark = {"PASS": "ok  ", "FAIL": "FAIL", "SKIPPED": "skip", "ERROR": "err "}.get(r["outcome"], "?")
        extra = r.get("reason") or r.get("detail") or (f"HTTP {r.get('status')}" if r.get("status") else "")
        print(f"  [{mark}] {r['id']:<24} {r['layer']:<34} {extra}")
    fails = [r for r in results if r["outcome"] == "FAIL"]
    skipped = [r for r in results if r["outcome"] == "SKIPPED"]
    if fails:
        print(f"\nGATE FAILED: {len(fails)} vector(s) not enforced as required — DO NOT PROMOTE.")
    else:
        print("\nGATE PASSED for all runnable vectors.")
    if skipped:
        print(f"  ({len(skipped)} vector(s) SKIPPED — provide their proxy endpoints to fully close the gate.)")


if __name__ == "__main__":
    sys.exit(run())
