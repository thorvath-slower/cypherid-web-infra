/**
 * CZID-328 — export-control access gate (Auth0 post-login Action).
 *
 * Gates access to export-controlled data/functions on a VERIFIED identity + export screening. This is
 * Layer 3 (true-origin assurance) where the network layers (1–2) structurally can't reach.
 *
 * FAIL-CLOSED by design: any error/timeout/uncertainty → deny. For a zero-tolerance posture, controlled
 * access is never granted on doubt.
 *
 * Provider-agnostic: the screening call is isolated in screen() — wire the chosen vendor's SDK/npm module
 * there (CZID-326/328 selection). It is left throwing on purpose so the gate fails CLOSED until a real
 * screen is configured — never return {hit:false} as a stub (that fails OPEN).
 *
 * COUNSEL-OWNED (not engineering): which data is export-controlled (classification), the screening lists +
 * the legally-correct response to a hit, the IDV method, and the vendor DPA (design doc §10 items 2,3,6).
 * This Action keys off a classification flag/role and an adapter — it does not decide the substance.
 *
 * Deploy: this is an Auth0 tenant Action (not IaC) — see README.md.
 */

exports.onExecutePostLogin = async (event, api) => {
  // 1. Scope — is this login touching export-controlled data/functions? Classification is counsel's.
  const controlled =
    event.client?.metadata?.export_controlled === "true" ||
    (event.authorization?.roles || []).includes("export-controlled");
  if (!controlled) return; // not in scope → no extra gate

  // 2. Verified identity/affiliation required for controlled access (method gated — CZID-328).
  if (!isVerifiedIdentity(event)) {
    audit(event, { decision: "deny", reason: "identity_unverified" });
    return api.access.deny("export_control_identity_unverified");
  }

  // 3. Export screening against denied/restricted-party lists — FAIL CLOSED on any error.
  let verdict;
  try {
    verdict = await screen(
      { userId: event.user.user_id, email: event.user.email, name: event.user.name },
      event.secrets // vendor creds injected by Auth0 secrets — never hard-coded
    );
  } catch (e) {
    audit(event, { decision: "deny", reason: "screening_error", error: String(e) });
    return api.access.deny("export_control_screening_unavailable");
  }

  if (verdict.hit) {
    audit(event, { decision: "deny", reason: "screening_hit", list: verdict.list });
    return api.access.deny("export_control_denied_party");
  }

  audit(event, { decision: "allow", reason: "screened_clear" });
};

/**
 * Verified identity/affiliation. The acceptable method is a counsel/identity decision (CZID-328) —
 * placeholder: an institutional SSO connection or a completed-IDV flag. Tighten per the chosen method.
 */
function isVerifiedIdentity(event) {
  const m = event.user.app_metadata || {};
  return m.identity_verified === true || event.connection?.strategy === "samlp";
}

/**
 * Provider-agnostic export screening — THE vendor swap point (CZID-328).
 * Contract:  screen(subject, secrets) -> { hit: boolean, list?: string, details?: object }
 *            MUST throw on any error/timeout so the gate fails closed.
 * Left throwing intentionally: until a real screening provider is wired, controlled access is denied.
 */
async function screen(_subject, _secrets) {
  throw new Error("export-screening provider not configured (CZID-328) — failing closed");
}

/** Structured decision record for the export-control evidence trail (CZID-331). */
function audit(event, record) {
  console.log(
    JSON.stringify({
      source: "export-control-access-gate",
      sub: event.user?.user_id,
      ip: event.request?.ip,
      ts: Date.now(),
      ...record,
    })
  );
}
