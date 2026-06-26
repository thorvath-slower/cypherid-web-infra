// CZID-327 shared helpers (no provider-specific logic here).

// Blocked-jurisdiction list — the AUTHORITATIVE, versioned list is counsel-owned (CZID-322). Baked
// into the artifact at build time OR read from SSM at cold start (draft §5); a list change is a
// redeploy, not a code edit. Mirrors the Layer-1 WAF geo baseline (CU/IR/KP/RU/SY/UA); kept here for
// the edge short-circuit + as defense-in-depth against the provider-resolved country.
const BLOCKED_COUNTRIES = new Set(["CU", "IR", "KP", "RU", "SY", "UA"]);

export function isBlockedCountry(code) {
  return !!code && BLOCKED_COUNTRIES.has(code.toUpperCase());
}

// CZID-331 audit log: emit one structured JSON record per decision. A CloudWatch subscription filter
// → Firehose → the immutable S3 store (Object Lock) centralizes the edge-region logs into the
// export-control evidence trail. Don't log more PII than the compliance record needs.
export function log(record) {
  try {
    console.log(JSON.stringify({ source: "edge-ip-intel", ...record }));
  } catch {
    console.log("edge-ip-intel: log serialization failed");
  }
}
