// CZID-327 — the provider-agnostic contract (the swap point). The handler consumes ONLY this; selecting
// the provider (CZID-326: geocomply | spur | ipqs) = changing PROVIDER + the secret, nothing else here.
//
// classify(ip, ctx) -> {
//   blocked: bool,          // provider-resolved country in the blocked set
//   vpn: bool, proxy: bool, tor: bool, hosting: bool, residentialProxy: bool,
//   riskScore: number,      // 0..100
//   country: string,        // ISO-3166 alpha-2 as the provider sees it
//   source: string          // provider name, for the CZID-331 audit record
// }

// Selected at build time (baked into config.mjs by build.sh) — viewer-request Lambda@Edge has no env
// vars. The committed placeholder resolves to "spur" so offline tests + local runs load the reference
// adapter; build.sh substitutes the counsel/procurement-chosen provider (CZID-326) at build time.
import { PROVIDER_NAME, isConfigured } from "../config.mjs";
const PROVIDER = isConfigured(PROVIDER_NAME) ? PROVIDER_NAME : "spur";

let _provider; // cached for the warm container lifetime
async function loadProvider() {
  if (_provider) return _provider;
  switch (PROVIDER) {
    case "geocomply":
      _provider = await import("./providers/geocomply.mjs");
      break;
    case "ipqs":
      _provider = await import("./providers/ipqs.mjs");
      break;
    case "spur":
    default:
      _provider = await import("./providers/spur.mjs");
      break;
  }
  return _provider;
}

export async function classify(ip, ctx) {
  const provider = await loadProvider();
  return provider.classify(ip, ctx);
}
