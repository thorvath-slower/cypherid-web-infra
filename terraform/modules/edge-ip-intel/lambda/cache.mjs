// CZID-284 — tiny in-memory LRU with per-entry TTL, keyed by client IP.
//
// PURPOSE: control provider spend + tail latency. A warm Lambda@Edge container serves many requests; a
// short-TTL verdict cache means we don't re-query the provider for the same IP within the TTL window.
// It lives only for the warm-container lifetime (no external store) and is bounded so it can never grow
// unbounded on a busy edge.
//
// SAFETY (fail-closed): the cache stores ONLY verdicts we already resolved. A provider error/timeout is
// never cached (the caller doesn't call set() on the error path), so a transient failure can't "stick" a
// deny-by-error into an allow later, and vice-versa — every failure re-attempts fail-closed on its own.
// Keep the TTL short so a since-changed IP reputation is re-evaluated quickly.

export class TtlLru {
  constructor({ max = 5000, ttlMs = 60_000 } = {}) {
    this.max = max;
    this.ttlMs = ttlMs;
    this.map = new Map(); // insertion-ordered; we use that for LRU eviction
  }

  get(key) {
    const e = this.map.get(key);
    if (!e) return undefined;
    if (Date.now() > e.expires) {
      this.map.delete(key);
      return undefined;
    }
    // refresh recency: delete + re-insert moves it to the end (most-recent)
    this.map.delete(key);
    this.map.set(key, e);
    return e.value;
  }

  set(key, value) {
    if (this.map.has(key)) this.map.delete(key);
    this.map.set(key, { value, expires: Date.now() + this.ttlMs });
    // evict oldest while over capacity
    while (this.map.size > this.max) {
      const oldest = this.map.keys().next().value;
      this.map.delete(oldest);
    }
  }

  get size() {
    return this.map.size;
  }
}
