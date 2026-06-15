# Bug Specification: Unproxied / unpinned dependencies — tail (bug-#012)

**Branch**: `bug-#012-unproxied-dependencies`  ·  **Spec dir**: `specs/012-unproxied-dependencies/`

**Created**: 2026-06-11 · **Status**: Draft · **Repo**: `cypherid-web-infra`

**Input**: The original `bug-#012` pass covered the four app/workflow/lambda repos. `cypherid-web-infra` was not included — its two Dockerfiles still pulled mutable base tags, and the grafana image had a **broken** checksum guard. Close that tail.

## Changes

**`docker/grafana/Dockerfile`**
- Base digest-pinned: `FROM ${BASE_REGISTRY}grafana/grafana:7.1.2@sha256:7558c103…`. The `@sha256` is authoritative, so the prior `ARG grafana_version=7.1.2` (which would be silently ignored once a digest is present) is removed; `${BASE_REGISTRY}` is the ECR pull-through hook.
- **Fixed the chamber checksum guard (real bug).** The Dockerfile declared `CHAMBER_SHA256SUM` but the `curl … chamber … | chmod | mv` **never verified it** — an unverified binary download of a *secrets* tool. Worse, the declared value (`c85bf50f…`) did **not** match the actual `chamber v2.7.5 linux-amd64` artifact. Corrected to the verified sha (`acc9fa8b…`, confirmed against the official GitHub release) and wired in `… | sha256sum -c -` so the build now fails on tampering/drift.

**`terraform/modules/idseq-s3-tar-writer/Dockerfile`**
- Base digest-pinned: `FROM ${BASE_REGISTRY}python:3.7-slim-bookworm@sha256:b53f496c…`.
- Added the non-secret `ARG PIP_INDEX_URL` routing hook + `pip config set global.index-url` before `pip install` (matches the bug-#012 pattern in the other repos).

## Verification

- Both digests resolve via `docker buildx imagetools inspect`.
- `docker build --check` on both: 0 errors (grafana has 1 pre-existing shell-form `ENTRYPOINT` warning, untouched).
- The corrected chamber sha was verified by downloading the real release artifact and comparing (`shasum -a 256`) — `acc9fa8b…` matches; the old value did not.

## Notes / non-goals

- grafana 7.1.2 and python 3.7 are themselves EOL; **pinning ≠ upgrading** (that's the runtime-EOL track). This makes them immutable/verifiable as-is; Renovate can later bump tag+digest together.
- This repo has no `renovate.json` yet (improvement-#009 added it to the three runtime-upgraded repos); adding one here is a small follow-up so these pins are auto-maintained.
- Live ECR pull-through / CodeArtifact remain Bucket B.
