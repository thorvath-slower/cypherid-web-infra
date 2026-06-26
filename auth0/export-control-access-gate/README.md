# Export-control access gate — Auth0 post-login Action (CZID-328)

Layer 3, identity half: gates access to **export-controlled** data/functions on a **verified identity** +
**export screening**, at the auth layer. The network layers (1–2) deny the evasion *channels*; this answers
"is this verified person actually entitled?" — closing the residential-proxy / stolen-identity gap as far as
identity can.

> This is an **Auth0 tenant Action**, not IaC. It lives here as the reviewed reference implementation; it
> deploys to the Auth0 tenant (via the Auth0 Deploy CLI or the `auth0` Terraform provider, wherever the tenant
> config is managed — likely the app side, not this infra repo).

## How it works (fail-closed)

1. **Scope** — only acts when the login touches export-controlled data/functions (a classification flag/role).
2. **Verified identity** required for controlled access — else deny.
3. **Export screening** against denied/restricted-party lists via the provider-agnostic `screen()` — **deny on
   a hit, and deny on any error/timeout** (fail-closed).
4. **Audit** — every decision is logged (same record shape as the Layer-2 edge + the CZID-331 evidence trail).

## Fail-closed default (important)

`screen()` is **left throwing on purpose**. Until a real screening provider is wired, the gate **denies all
controlled access** — never returns `{hit:false}` as a stub, which would fail *open*. Wire the chosen vendor
(CZID-326/328) into `screen()`, with creds injected via **Auth0 Action secrets** (never hard-coded).

## What's counsel-owned (not engineering)

- **Data classification** — which data/functions are export-controlled, deemed-export scope (CZID-322/328).
- **Screening lists + hit-handling** — which lists (OFAC SDN, BIS Entity List, …) and the legally-correct
  response to a hit (CZID-328).
- **IDV method** — what counts as a "verified" identity.
- **Vendor + DPA** — the screening/IDV vendor and its data-processing agreement (CZID-328 §10 items 3,6).

The Action keys off a classification flag and an adapter; it does **not** decide any of the above.

## Validate / test

`node --check access-gate.action.js` for syntax. Functional testing is via the Auth0 Action test harness in the
tenant (mock `event`/`api`), since it depends on the Auth0 runtime + secrets.

See `../../EXPORT-CONTROL-LAYER3-DESIGN.md` for the full Layer-3 design + the CZID-329 device-attestation spike.
