#!/usr/bin/env bash
# Build the edge-ip-intel Lambda@Edge artifact (CZID-327 / CZID-284).
#
# SSOT: copies the ONE authoritative blocked-jurisdiction list
# (export-control/blocked-jurisdictions.json, CZID-322) into the bundle, so the Lambda and the Layer-1
# WAF read the SAME source and cannot drift. The copied JSON and the zip are build artifacts (gitignored)
# — never maintain a second list by hand.
#
# BAKED CONFIG (CZID-284): a viewer-request Lambda@Edge has NO user environment variables, so the two
# runtime inputs that would normally be env vars — the provider secret ARN and the provider name — are
# substituted into config.mjs at build time from Terraform-provided values, then bundled. The committed
# config.mjs carries inert @@PLACEHOLDER@@ tokens so the source tree never holds a real ARN and the
# offline `node --test` suite runs unchanged. We substitute into a COPY (config.built.mjs) and zip that
# in as config.mjs, so the working tree's placeholders are never mutated.
#
# NO node_modules: stdlib-only bundle (Node built-in https + crypto do the provider call + SigV4 secret
# read). Keeps the artifact under the 1 MB viewer-request limit.
#
# Env inputs (optional; empty leaves the safe placeholder → the Lambda fails CLOSED until configured):
#   PROVIDER_SECRET_ARN   Secrets Manager ARN of the provider API key (us-east-1 replica)
#   PROVIDER_NAME         geocomply | spur | ipqs  (default: spur, the CZID-326 engineering lean)
#
# Output: edge-ip-intel.zip (< 1 MB, the viewer-request limit), consumed via the module's var.lambda_zip.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../../../export-control/blocked-jurisdictions.json" # the single source
out="${1:-$here/edge-ip-intel.zip}"

: "${PROVIDER_NAME:=spur}"
: "${PROVIDER_SECRET_ARN:=}"

[ -f "$src" ] || { echo "missing single source: $src" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip not found" >&2; exit 1; }

# Bring the SSOT list into the bundle (derived, gitignored).
cp "$src" "$here/blocked-jurisdictions.json"

# Bake config into a derived copy (never mutate the committed placeholder file). If an input is empty the
# @@TOKEN@@ survives → config.mjs isConfigured() returns false → the Lambda fails CLOSED (no auth path).
sed \
  -e "s|@@PROVIDER_SECRET_ARN@@|${PROVIDER_SECRET_ARN}|g" \
  -e "s|@@PROVIDER_NAME@@|${PROVIDER_NAME}|g" \
  "$here/config.mjs" > "$here/config.built.mjs"

# Zip from a clean staging dir so the BAKED config lands in the archive as config.mjs (imports resolve
# unchanged) while the committed placeholder config.mjs in the working tree is never mutated. Stdlib only
# — no node_modules.
stage="$(mktemp -d)"
cp "$here/index.mjs" "$here/lib.mjs" "$here/secrets.mjs" "$here/cache.mjs" \
   "$here/blocked-jurisdictions.json" "$stage/"
cp -R "$here/adapter" "$stage/adapter"
cp "$here/config.built.mjs" "$stage/config.mjs" # baked copy → archived as config.mjs
( cd "$stage" && rm -f "$out" \
  && zip -qr "$out" index.mjs lib.mjs secrets.mjs cache.mjs config.mjs adapter blocked-jurisdictions.json )
rm -rf "$stage" "$here/config.built.mjs"
echo "built $out ($(du -h "$out" | cut -f1)) provider=${PROVIDER_NAME} secret_arn=$([ -n "$PROVIDER_SECRET_ARN" ] && echo set || echo UNSET-fail-closed)"
