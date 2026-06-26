#!/usr/bin/env bash
# Build the edge-ip-intel Lambda@Edge artifact (CZID-327).
#
# SSOT: copies the ONE authoritative blocked-jurisdiction list
# (export-control/blocked-jurisdictions.json, CZID-322) into the bundle, so the Lambda and the Layer-1
# WAF read the SAME source and cannot drift. The copied JSON and the zip are build artifacts (gitignored)
# — never maintain a second list by hand.
#
# Output: edge-ip-intel.zip (< 1 MB, the viewer-request limit), consumed via the module's var.lambda_zip.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../../../export-control/blocked-jurisdictions.json" # the single source
out="${1:-$here/edge-ip-intel.zip}"

[ -f "$src" ] || { echo "missing single source: $src" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip not found" >&2; exit 1; }

# Bring the SSOT list into the bundle (derived, gitignored).
cp "$src" "$here/blocked-jurisdictions.json"

# Zip the Lambda sources + the copied list. Stdlib only — no node_modules.
( cd "$here" && rm -f "$out" && zip -qr "$out" index.mjs lib.mjs adapter blocked-jurisdictions.json )
echo "built $out ($(du -h "$out" | cut -f1))"
