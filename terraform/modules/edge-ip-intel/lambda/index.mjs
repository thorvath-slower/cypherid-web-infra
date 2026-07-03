// CZID-327 — Layer 2 Lambda@Edge handler (viewer-request). Provider-agnostic: the decision logic here
// consumes ONLY the common adapter contract (adapter/index.mjs), so swapping GeoComply/Spur/IPQS
// (CZID-326) changes nothing in this file. FAIL-CLOSED: any provider error/timeout → 403.
//
// CZID-330 — zero-tolerance fail-closed. The rule is DENY on error, timeout, OR ambiguity. "Ambiguity"
// is explicit here: a missing viewer country, an unparseable/empty client IP, or a verdict that is
// missing or shaped wrong all count as "we cannot affirmatively confirm this request is allowed" and
// therefore DENY. There is no "allow on uncertainty" path. The ONLY way to reach `allow` is a fully
// resolved, well-formed, clean verdict for a known, non-blocked country.
//
// Limits (viewer-request): 5s timeout, 128MB, <1MB code+deps, NO env vars, no VPC.

import { classify } from "./adapter/index.mjs";
import { isBlockedCountry, log } from "./lib.mjs";

const RISK_THRESHOLD = 85;
// Canary (CZID-327 §10): when true, log the would-be decision but always forward the request.
// Baked into the artifact at build time (no env vars at the edge); flip + redeploy to enforce.
// NOTE (CZID-330): DRY_RUN is a fail-OPEN canary by design (log-only, always forward). It exists ONLY
// for pre-go-live tuning and MUST be false before counsel go-live. The go-live checklist and the
// evasion harness (CZID-333) verify DRY_RUN === false as a gate.
const DRY_RUN = false;

// Lambda@Edge entry point. Delegates to the pure, testable core with the real provider classify().
export async function handler(event) {
  return decideRequest(event, { classify });
}

// Pure decision core (CZID-330). `deps.classify` is injected so the fail-closed behavior can be tested
// without a live provider. Returns either the (possibly modified) request to forward, or a 403 object.
export async function decideRequest(event, deps) {
  const classifyFn = deps.classify;
  const req = event.Records[0].cf.request;
  const h = req.headers;
  const viewerCountry = h["cloudfront-viewer-country"]?.[0]?.value;
  // cloudfront-viewer-address is "ip:port" (IPv4) or "[ip]:port" (IPv6); strip the trailing port.
  const rawAddr = h["cloudfront-viewer-address"]?.[0]?.value || req.clientIp || "";
  const ip = rawAddr.replace(/^\[/, "").replace(/\]?:\d+$/, "");

  // 0. Ambiguity guard (CZID-330). If CloudFront could not resolve the viewer country, we cannot make
  // the geo determination the mandate requires → DENY. Do NOT fall through to the provider hoping it
  // fills the gap; an unknown origin is exactly the uncertainty zero-tolerance forbids allowing.
  if (!viewerCountry) {
    return decide(req, { decision: "deny", reason: "ambiguous_no_country", ip });
  }
  // If we have no usable client IP, the IP-intel layer cannot screen for VPN/proxy/residential → DENY.
  if (!isUsableIp(ip)) {
    return decide(req, { decision: "deny", reason: "ambiguous_no_ip", viewerCountry, ip });
  }

  // 1. Geo short-circuit — no provider call needed (cheap, and the blocked list is counsel-owned, CZID-322).
  if (isBlockedCountry(viewerCountry)) {
    return decide(req, { decision: "deny", reason: "geo", viewerCountry, ip });
  }

  // 2. Anonymizer / residential-proxy / risk verdict — FAIL CLOSED on any error.
  let verdict;
  try {
    verdict = await classifyFn(ip, { viewerCountry });
  } catch (e) {
    return decide(req, { decision: "deny", reason: "provider_error", error: String(e), ip, viewerCountry });
  }

  // 2a. Verdict-shape guard (CZID-330). A malformed/partial verdict (provider returned 200 with an
  // unexpected body, a missing riskScore, or non-boolean flags) is ambiguity → DENY. We do NOT let a
  // silently-falsy field (undefined flag, NaN score) coerce into "not bad" and slip through to allow.
  if (!isWellFormedVerdict(verdict)) {
    return decide(req, { decision: "deny", reason: "ambiguous_verdict", ip, viewerCountry, verdict });
  }

  const bad =
    verdict.blocked || verdict.vpn || verdict.proxy || verdict.tor ||
    verdict.hosting || verdict.residentialProxy || verdict.riskScore >= RISK_THRESHOLD;

  if (bad) {
    return decide(req, { decision: "deny", reason: "anonymizer_or_risk", ip, viewerCountry, verdict });
  }
  return decide(req, { decision: "allow", ip, viewerCountry, verdict });
}

// A usable IP is a non-empty string that is not one of the CloudFront "unknown" sentinels. We keep the
// check permissive on format (the provider validates the address itself and THROWS on a bad one, which
// fails closed) but reject the cases where we plainly have nothing to screen.
export function isUsableIp(ip) {
  if (typeof ip !== "string") return false;
  const v = ip.trim();
  if (v === "" || v === "-" || v.toLowerCase() === "unknown") return false;
  return true;
}

// The verdict must carry every boolean flag as a real boolean and a finite numeric riskScore. Anything
// else means we cannot trust the "clean" reading → treat as ambiguous (caller denies). This is the
// structural guarantee that a partial provider response can never coerce into an allow.
export function isWellFormedVerdict(v) {
  if (!v || typeof v !== "object") return false;
  const flags = ["blocked", "vpn", "proxy", "tor", "hosting", "residentialProxy"];
  for (const f of flags) {
    if (typeof v[f] !== "boolean") return false;
  }
  if (typeof v.riskScore !== "number" || !Number.isFinite(v.riskScore)) return false;
  return true;
}

// Single decision point so DRY_RUN and the CZID-331 audit log are consistent for allow + deny.
function decide(req, ctx) {
  log({ ...ctx, dryRun: DRY_RUN, ts: Date.now() });
  if (ctx.decision === "allow" || DRY_RUN) return req; // forward to origin (ALB + Layer-1 WAF)
  return {
    status: "403",
    statusDescription: "Forbidden",
    headers: { "content-type": [{ key: "Content-Type", value: "text/plain" }] },
    // TODO(counsel) CZID-330: the exact user-facing denial wording has legal weight and MUST be
    // drafted/approved by counsel, not engineering. This is a neutral placeholder only.
    body: "Access denied: this service is unavailable from your location or network.",
  };
}
