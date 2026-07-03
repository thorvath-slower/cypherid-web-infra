// CZID-330 — fail-closed unit tests for the Layer-2 edge handler. Runs under `node --test` with only
// the Node stdlib (no provider creds, no network). Proves that every error/timeout/ambiguity vector
// resolves to DENY (a 403 response object), and that the ONLY allow path is a clean, well-formed
// verdict for a known non-blocked country.
//
// The pure core `decideRequest(event, { classify })` takes an injected classify(), so we exercise the
// provider-error, malformed-verdict, bad-verdict, and clean-allow branches with a stub — no network.
//
// Run: node --test terraform/modules/edge-ip-intel/lambda/test/
import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const lambdaDir = join(here, "..");

// build.sh copies the SSOT list into the bundle at build time; for the test we drop a fixture
// (blocked-jurisdictions.json is gitignored) so lib.mjs can load it at import time.
writeFileSync(
  join(lambdaDir, "blocked-jurisdictions.json"),
  JSON.stringify({ blocked_country_codes: ["CU", "IR", "KP", "SY", "RU"] }),
);

const { decideRequest, isUsableIp, isWellFormedVerdict } = await import("../index.mjs");

// A CloudFront viewer-request event builder.
function event({ country, address }) {
  const headers = {};
  if (country !== undefined) headers["cloudfront-viewer-country"] = [{ key: "CloudFront-Viewer-Country", value: country }];
  if (address !== undefined) headers["cloudfront-viewer-address"] = [{ key: "CloudFront-Viewer-Address", value: address }];
  return { Records: [{ cf: { request: { headers, clientIp: "" } } }] };
}

const isDeny = (r) => r && r.status === "403";
const isForward = (r) => r && r.headers && r.status === undefined && r.Records === undefined;

const cleanVerdict = {
  blocked: false, vpn: false, proxy: false, tor: false, hosting: false,
  residentialProxy: false, riskScore: 3, country: "US", source: "test",
};
const throwClassify = async () => { throw new Error("provider timeout"); };
const okClassify = async () => cleanVerdict;

test("DENY when CloudFront cannot resolve the viewer country (ambiguity)", async () => {
  const r = await decideRequest(event({ address: "203.0.113.7:443" }), { classify: okClassify });
  assert.ok(isDeny(r), "missing country must 403");
});

test("DENY when there is no usable client IP (ambiguity)", async () => {
  const r = await decideRequest(event({ country: "US", address: "" }), { classify: okClassify });
  assert.ok(isDeny(r), "empty IP must 403");
});

test("DENY for the CloudFront 'unknown' IP sentinel (ambiguity)", async () => {
  const r = await decideRequest(event({ country: "US", address: "unknown" }), { classify: okClassify });
  assert.ok(isDeny(r), "sentinel IP must 403");
});

test("DENY for a blocked jurisdiction (geo short-circuit, no provider call)", async () => {
  let called = false;
  const spy = async () => { called = true; return cleanVerdict; };
  const r = await decideRequest(event({ country: "IR", address: "203.0.113.7:443" }), { classify: spy });
  assert.ok(isDeny(r), "blocked country must 403");
  assert.equal(called, false, "geo block must short-circuit before the provider");
});

test("DENY on provider error/timeout (fail-closed)", async () => {
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: throwClassify });
  assert.ok(isDeny(r), "provider throw must 403");
});

test("DENY on a malformed/partial verdict (ambiguity — cannot coerce to allow)", async () => {
  // Missing riskScore + undefined flags: the OLD code would compute bad=false and ALLOW. New: DENY.
  const partial = async () => ({ vpn: undefined, country: "US" });
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: partial });
  assert.ok(isDeny(r), "malformed verdict must 403");
});

test("DENY on a NaN riskScore (ambiguity)", async () => {
  const nanScore = async () => ({ ...cleanVerdict, riskScore: NaN });
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: nanScore });
  assert.ok(isDeny(r), "NaN score must 403");
});

test("DENY on a bad verdict (vpn flagged)", async () => {
  const vpn = async () => ({ ...cleanVerdict, vpn: true });
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: vpn });
  assert.ok(isDeny(r), "vpn must 403");
});

test("DENY on a high risk score at/over threshold", async () => {
  const risky = async () => ({ ...cleanVerdict, riskScore: 85 });
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: risky });
  assert.ok(isDeny(r), "riskScore>=85 must 403");
});

test("ALLOW only for a clean, well-formed verdict + known non-blocked country", async () => {
  const r = await decideRequest(event({ country: "US", address: "203.0.113.7:443" }), { classify: okClassify });
  assert.ok(isForward(r), "clean request must forward to origin");
});

test("guards: isUsableIp / isWellFormedVerdict", () => {
  assert.equal(isUsableIp(""), false);
  assert.equal(isUsableIp("-"), false);
  assert.equal(isUsableIp("unknown"), false);
  assert.equal(isUsableIp("203.0.113.7"), true);
  assert.equal(isWellFormedVerdict(null), false);
  assert.equal(isWellFormedVerdict({}), false);
  assert.equal(isWellFormedVerdict({ ...cleanVerdict }), true);
  assert.equal(isWellFormedVerdict({ ...cleanVerdict, riskScore: "3" }), false);
});
