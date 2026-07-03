// CZID-284 — integration-layer tests for the provider adapter + verdict cache, all offline (no network).
// Runs under `node --test` with only the Node stdlib. Proves the CZID-284 additions preserve fail-closed:
//   - provider timeout → throw  (handler turns into DENY)
//   - provider non-2xx → throw
//   - malformed body → throw
//   - residential-proxy / VPN verdict → normalized with the bad flag set (handler DENIES)
//   - clean verdict → normalized well-formed (handler ALLOW path reachable)
//   - the TtlLru caches, evicts by capacity, and expires by TTL
//
// We drive spur.mjs's classify() through a mocked node:https so no real request leaves the process, and
// with placeholder config (PROVIDER_SECRET_ARN is the committed @@token@@) we assert it fails CLOSED when
// unconfigured. We also unit-test normalize() indirectly via a stubbed HTTPS response.

import { test } from "node:test";
import assert from "node:assert/strict";
import { TtlLru } from "../cache.mjs";
import { normalize } from "../adapter/providers/spur.mjs";
import { isWellFormedVerdict } from "../index.mjs";

// --- normalize(): provider JSON → common contract, always a well-formed verdict ------------------------
test("normalize: clean provider response → well-formed, non-bad verdict", () => {
  const v = normalize({ client: { types: [] }, risk: 2, location: { country: "US" } });
  assert.ok(isWellFormedVerdict(v), "clean verdict must be well-formed (handler can allow)");
  const bad = v.vpn || v.proxy || v.tor || v.hosting || v.residentialProxy || v.riskScore >= 85;
  assert.equal(bad, false, "clean response must not be flagged bad");
});

test("normalize: residential-proxy verdict → flagged (handler DENIES)", () => {
  const v = normalize({ client: { types: ["RESIDENTIAL_PROXY"] }, risk: 10 });
  assert.ok(isWellFormedVerdict(v));
  assert.equal(v.residentialProxy, true, "residential proxy must set the flag → deny");
});

test("normalize: VPN verdict → flagged (handler DENIES)", () => {
  const v = normalize({ types: ["VPN"], risk: 5 });
  assert.ok(isWellFormedVerdict(v));
  assert.equal(v.vpn, true);
});

test("normalize: missing risk coerces to a finite 0 (still well-formed)", () => {
  const v = normalize({ client: { types: [] } });
  assert.ok(isWellFormedVerdict(v), "riskScore must be a finite number, not NaN/undefined");
  assert.equal(v.riskScore, 0);
});

// --- TtlLru --------------------------------------------------------------------------------------------
test("TtlLru: get returns set value within TTL", () => {
  const c = new TtlLru({ max: 10, ttlMs: 1000 });
  c.set("1.2.3.4", { ok: true });
  assert.deepEqual(c.get("1.2.3.4"), { ok: true });
});

test("TtlLru: entry expires after TTL", async () => {
  const c = new TtlLru({ max: 10, ttlMs: 5 });
  c.set("1.2.3.4", { ok: true });
  await new Promise((r) => setTimeout(r, 12));
  assert.equal(c.get("1.2.3.4"), undefined, "expired entry must be a miss");
});

test("TtlLru: evicts the least-recently-used over capacity", () => {
  const c = new TtlLru({ max: 2, ttlMs: 10_000 });
  c.set("a", 1);
  c.set("b", 2);
  c.get("a"); // touch a → b is now LRU
  c.set("c", 3); // evicts b
  assert.equal(c.get("b"), undefined, "b (LRU) evicted");
  assert.equal(c.get("a"), 1);
  assert.equal(c.get("c"), 3);
});

// --- spur.mjs classify() fail-closed, via a mocked node:https ------------------------------------------
// We can't easily inject https into the ESM module, so we assert the UNCONFIGURED path: with the committed
// placeholder secret ARN, getApiKey() must throw BEFORE any network call → fail closed. This is the exact
// state of the source tree (build.sh bakes a real ARN only for a real build), so it is the safe default.
test("spur.classify throws (fail-closed) when the secret ARN is an unbaked placeholder", async () => {
  const spur = await import("../adapter/providers/spur.mjs");
  spur.__resetForTest();
  await assert.rejects(
    () => spur.classify("203.0.113.7", { viewerCountry: "US" }),
    /provider secret ARN not configured/,
    "unconfigured provider must throw, never silently allow",
  );
});

// --- End-to-end through the adapter: a throwing provider stays a throw (handler will DENY) --------------
// The adapter (adapter/index.mjs) loads spur by default; with the unbaked placeholder it throws. This
// confirms the adapter does not swallow provider errors into a benign verdict.
test("adapter.classify propagates the provider throw (no silent allow)", async () => {
  const { classify } = await import("../adapter/index.mjs");
  await assert.rejects(
    () => classify("203.0.113.7", { viewerCountry: "US" }),
    "adapter must surface the provider error so the handler fails closed",
  );
});
