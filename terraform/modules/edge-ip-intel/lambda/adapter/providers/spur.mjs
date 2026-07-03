// CZID-326/284 — reference provider implementation (Spur). geocomply.mjs / ipqs.mjs would follow the
// SAME shape; each maps the provider's response onto the common contract in adapter/index.mjs. The FINAL
// provider is chosen by the CZID-326 RFP/PoC + counsel/procurement — this is a working skeleton behind
// the PROVIDER_NAME constant, not a committed vendor.
//
// CZID-284 integration constraints (all satisfied here):
//   - Node built-in `https` only. NO @aws-sdk/* — a viewer-request Lambda@Edge has a 1 MB code limit and
//     build.sh bundles stdlib-only (no node_modules).
//   - API key from Secrets Manager at COLD START, cached for the warm container. Never an env var, never
//     hardcoded. The ARN is baked into config.mjs by build.sh (Lambda@Edge has no user env vars).
//   - Hard per-call timeout inside the viewer-request budget.
//   - Verdict cache (TtlLru keyed by client IP, short TTL) to cap provider spend + latency.
//   - FAIL-CLOSED: any error/timeout/non-2xx/malformed body THROWS → the handler turns it into a 403.
//     There is no allow path in here.

import https from "node:https";
import { PROVIDER_SECRET_ARN, SECRET_REGION, isConfigured } from "../../config.mjs";
import { getSecretValue } from "../../secrets.mjs";
import { TtlLru } from "../../cache.mjs";

const PROVIDER_TIMEOUT_MS = 800; // well inside the 5s viewer-request limit; fail-closed stays fast
const CACHE = new TtlLru({ max: 5000, ttlMs: 60_000 }); // 1-min verdict cache, keyed by IP

// --- Secret (API key) fetch: once at cold start, cached for the warm container ---
let _keyPromise; // memoize the in-flight/settled fetch so concurrent invocations share one call
async function getApiKey() {
  if (_keyPromise) return _keyPromise;
  _keyPromise = (async () => {
    if (!isConfigured(PROVIDER_SECRET_ARN)) {
      // build.sh did not bake a real ARN → we cannot authenticate → fail closed.
      throw new Error("spur: provider secret ARN not configured");
    }
    const res = await getSecretValue(PROVIDER_SECRET_ARN, SECRET_REGION, 1500);
    // The secret is stored as a raw token string, or as JSON {"api_key":"..."}. Accept either; anything
    // else is a misconfiguration → throw (fail closed).
    let key = res?.SecretString;
    if (!key) throw new Error("spur: empty secret");
    if (key.trim().startsWith("{")) {
      try {
        const j = JSON.parse(key);
        key = j.api_key ?? j.apiKey ?? j.token ?? j.SPUR_API_KEY;
      } catch {
        throw new Error("spur: malformed secret json");
      }
    }
    if (!key || typeof key !== "string") throw new Error("spur: no api key in secret");
    return key;
  })().catch((e) => {
    // Do not memoize a failure — let the next cold-start attempt retry (still fail-closed meanwhile).
    _keyPromise = undefined;
    throw e;
  });
  return _keyPromise;
}

// --- One HTTPS GET with a hard timeout, using only node:https ---
function httpsGetJson(url, headers, timeoutMs) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, { method: "GET", headers, timeout: timeoutMs }, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          return reject(new Error(`spur ${res.statusCode}`)); // non-2xx → fail closed
        }
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error("spur: malformed body")); // unparseable → fail closed
        }
      });
    });
    req.on("timeout", () => req.destroy(new Error("spur: timeout"))); // → fail closed
    req.on("error", reject);
    req.end();
  });
}

export async function classify(ip /*, ctx */) {
  const cached = CACHE.get(ip);
  if (cached !== undefined) return cached;

  const key = await getApiKey();
  const j = await httpsGetJson(
    `https://api.spur.us/v2/context/${encodeURIComponent(ip)}`,
    { Authorization: `Token ${key}`, Accept: "application/json" },
    PROVIDER_TIMEOUT_MS,
  );
  const verdict = normalize(j);
  // Only well-resolved verdicts reach here (any error above threw); cache it for the short TTL.
  CACHE.set(ip, verdict);
  return verdict;
}

// Map the Spur response onto the common contract. Field names are illustrative — confirm against the
// live Spur schema during the CZID-326 PoC. Exported for the offline test suite.
export function normalize(j) {
  const t = j?.client?.types || j?.types || [];
  const has = (x) => Array.isArray(t) && t.includes(x);
  return {
    blocked: false, // country-block decided by isBlockedCountry() / WAF; provider country below
    vpn: has("VPN") || !!j?.vpn,
    proxy: has("PROXY") || !!j?.proxy,
    tor: has("TOR") || !!j?.tor,
    hosting: has("HOSTING") || has("DATACENTER"),
    residentialProxy: has("RESIDENTIAL_PROXY") || !!j?.residential_proxy,
    riskScore: Number(j?.risk ?? j?.risk_score ?? 0),
    country: j?.location?.country || j?.country || "",
    source: "spur",
  };
}

// Exposed for the offline test suite (network-free): reset the module caches between cases.
export function __resetForTest() {
  _keyPromise = undefined;
  CACHE.map.clear();
}
