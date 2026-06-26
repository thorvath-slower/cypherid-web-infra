// CZID-327 — Layer 2 Lambda@Edge handler (viewer-request). Provider-agnostic: the decision logic here
// consumes ONLY the common adapter contract (adapter/index.mjs), so swapping GeoComply/Spur/IPQS
// (CZID-326) changes nothing in this file. FAIL-CLOSED: any provider error/timeout → 403.
//
// Limits (viewer-request): 5s timeout, 128MB, <1MB code+deps, NO env vars, no VPC.

import { classify } from "./adapter/index.mjs";
import { isBlockedCountry, log } from "./lib.mjs";

const RISK_THRESHOLD = 85;
// Canary (CZID-327 §10): when true, log the would-be decision but always forward the request.
// Baked into the artifact at build time (no env vars at the edge); flip + redeploy to enforce.
const DRY_RUN = false;

export async function handler(event) {
  const req = event.Records[0].cf.request;
  const h = req.headers;
  const viewerCountry = h["cloudfront-viewer-country"]?.[0]?.value;
  // cloudfront-viewer-address is "ip:port" (IPv4) or "[ip]:port" (IPv6); strip the trailing port.
  const rawAddr = h["cloudfront-viewer-address"]?.[0]?.value || req.clientIp || "";
  const ip = rawAddr.replace(/^\[/, "").replace(/\]?:\d+$/, "");

  // 1. Geo short-circuit — no provider call needed (cheap, and the blocked list is counsel-owned, CZID-322).
  if (isBlockedCountry(viewerCountry)) {
    return decide(req, { decision: "deny", reason: "geo", viewerCountry, ip });
  }

  // 2. Anonymizer / residential-proxy / risk verdict — FAIL CLOSED on any error.
  let verdict;
  try {
    verdict = await classify(ip, { viewerCountry });
  } catch (e) {
    return decide(req, { decision: "deny", reason: "provider_error", error: String(e), ip });
  }

  const bad =
    verdict.blocked || verdict.vpn || verdict.proxy || verdict.tor ||
    verdict.hosting || verdict.residentialProxy || verdict.riskScore >= RISK_THRESHOLD;

  if (bad) {
    return decide(req, { decision: "deny", reason: "anonymizer_or_risk", ip, viewerCountry, verdict });
  }
  return decide(req, { decision: "allow", ip, viewerCountry, verdict });
}

// Single decision point so DRY_RUN and the CZID-331 audit log are consistent for allow + deny.
function decide(req, ctx) {
  log({ ...ctx, dryRun: DRY_RUN, ts: Date.now() });
  if (ctx.decision === "allow" || DRY_RUN) return req; // forward to origin (ALB + Layer-1 WAF)
  return {
    status: "403",
    statusDescription: "Forbidden",
    headers: { "content-type": [{ key: "Content-Type", value: "text/plain" }] },
    // CZID-330: the exact user-facing wording is counsel-approved — placeholder here.
    body: "Access denied: this service is unavailable from your location or network.",
  };
}
