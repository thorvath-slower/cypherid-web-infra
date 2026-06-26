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

// Selected at build time (baked) or via SSM at cold start — viewer-request Lambda@Edge has no env vars.
const PROVIDER = "spur"; // geocomply | spur | ipqs — set by the build per CZID-326.

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
