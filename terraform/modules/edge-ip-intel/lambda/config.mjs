// CZID-284 — build-time-baked configuration for the Layer-2 edge Lambda.
//
// Lambda@Edge (viewer-request) has NO environment variables, so every runtime input that would normally
// be an env var is instead BAKED into the artifact by build.sh at build time and read from here. build.sh
// rewrites this file's placeholder tokens (@@PROVIDER_SECRET_ARN@@, @@PROVIDER_NAME@@) from the
// Terraform-provided values before it zips. The committed version below carries safe, inert placeholders
// so the source tree never contains a real secret ARN and the `node --test` suite runs offline.
//
// SECURITY: this file holds ONLY the *reference* (a Secrets Manager ARN) — never a key value. The API key
// itself lives in Secrets Manager (counsel/ops-provisioned) and is fetched at cold start (see
// adapter/providers/spur.mjs). Nothing here is a credential.

// The Secrets Manager ARN of the provider API key. Baked by build.sh from var.provider_secret_arn.
// The placeholder token is replaced at build time; the literal below is intentionally not a real ARN.
export const PROVIDER_SECRET_ARN = "@@PROVIDER_SECRET_ARN@@";

// Region the secret is read from. Lambda@Edge runs the code in the nearest edge region, but the AWS APIs
// it calls must target a real region; Secrets Manager for this program is pinned to us-east-1 (where the
// Lambda@Edge version + its secret replica live). Not a placeholder — this is fixed by the design.
export const SECRET_REGION = "us-east-1";

// Which provider adapter to load (geocomply | spur | ipqs). Baked by build.sh from var.provider_name.
// Default here is "spur" — the CZID-326 engineering lean — but the FINAL choice is counsel/procurement's.
export const PROVIDER_NAME = "@@PROVIDER_NAME@@";

// Helper: has build.sh substituted the token, or are we running the committed placeholder (offline tests)?
export function isConfigured(v) {
  return typeof v === "string" && v.length > 0 && !v.startsWith("@@");
}
