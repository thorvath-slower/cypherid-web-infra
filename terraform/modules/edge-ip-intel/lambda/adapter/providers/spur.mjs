// CZID-326/327 — example provider implementation (Spur). geocomply.mjs / ipqs.mjs follow the SAME shape;
// each maps the provider's response onto the common contract in adapter/index.mjs. The actual provider
// is chosen by the CZID-326 RFP/PoC + counsel; this is a working skeleton, not a committed vendor.

import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

// Secrets Manager fetch at cold start, cached for the warm container (draft §5 — no env vars at the edge).
let _key;
async function getSecret() {
  if (_key) return _key;
  // The secret ARN is baked at build time or read from SSM; region pinned to us-east-1 for Lambda@Edge.
  const arn = process.env.PROVIDER_SECRET_ARN; // injected by the build step, not a runtime env var
  const sm = new SecretsManagerClient({ region: "us-east-1" });
  const res = await sm.send(new GetSecretValueCommand({ SecretId: arn }));
  _key = res.SecretString;
  return _key;
}

async function fetchWithTimeout(url, opts, ms) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: ctrl.signal });
  } finally {
    clearTimeout(t);
  }
}

export async function classify(ip /*, ctx */) {
  const key = await getSecret();
  // Low timeout so fail-closed (handled in index.mjs) stays fast (draft §9).
  const r = await fetchWithTimeout(
    `https://api.spur.us/v2/context/${encodeURIComponent(ip)}`,
    { headers: { Authorization: `Token ${key}` } },
    800,
  );
  if (!r.ok) throw new Error(`spur ${r.status}`); // → fail closed in the handler
  const j = await r.json();
  return normalize(j);
}

// Map the Spur response onto the common contract. Field names are illustrative — confirm against the
// live Spur schema during the CZID-326 PoC.
function normalize(j) {
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
