// CZID-327 shared helpers (no provider-specific logic here).

import { readFileSync } from "node:fs";

// Blocked-jurisdiction list — read from the SINGLE SOURCE OF TRUTH, blocked-jurisdictions.json
// (counsel-owned, CZID-322), which build.sh copies into this bundle from
// export-control/blocked-jurisdictions.json. The Layer-1 WAF reads the SAME file via Terraform, so the
// two layers cannot drift. NEVER hard-code the list here — a change happens in that one JSON only.
// Loaded once at module init (synchronous, local file — fine for the viewer-request budget).
const BLOCKED_COUNTRIES = new Set(
  JSON.parse(
    readFileSync(new URL("./blocked-jurisdictions.json", import.meta.url), "utf8")
  ).blocked_country_codes.map((c) => c.toUpperCase())
);

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
