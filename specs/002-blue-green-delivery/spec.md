# Feature Specification: Blue/Green Delivery — deploy wiring (feature-#002)

**Branch**: `feature-#002-blue-green-delivery`  ·  **Spec dir**: `specs/002-blue-green-delivery/`

**Created**: 2026-06-10 · **Status**: Draft · **Repo**: `cypherid-web-infra` (deploy half)

**Gated item — tests-first.** Companion app-side spec: `seqtoid-web` `specs/002-blue-green-delivery/` (the Helm chart).

**Input**: Deliver the `seqtoid-web` blue/green chart to EKS via Argo CD GitOps, with the controller bootstrap, per-environment config, and the promotion gates Tom asked for (automated + manual).

## Why

This repo is the deploy/config home. Following GitOps best practice, the app chart lives with the app (`seqtoid-web`) and this repo supplies the environment values + the Argo CD `Application`s that bind them — via Argo CD **multiple sources** (`$values`). That keeps chart and config independently versioned with the least cross-repo coupling.

## What this delivers — `deploy/argocd/`

- **`projects/czid.yaml`** — an `AppProject` scoping allowed source repos (app chart, this repo, the argo-helm chart repo) and destination namespaces (`czid-dev/staging/prod`, `argo-rollouts`).
- **`bootstrap/root-app.yaml`** — the app-of-apps root `Application` (recurses `apps/`); apply once, then everything is GitOps-managed.
- **`apps/argo-rollouts.yaml`** — installs the Argo Rollouts controller + dashboard (pinned chart `2.39.0`, `ServerSideApply` for the large CRDs).
- **`apps/seqtoid-web-{dev,staging,prod}.yaml`** — multi-source `Application`s: chart from `seqtoid-web` + `valueFiles: $values/.../seqtoid-web/<env>.yaml` from this repo.
- **`values/seqtoid-web/{dev,staging,prod}.yaml`** — per-env overrides.
- **`bootstrap/README.md`** (install) and **`deploy/RUNBOOK.md`** (day-2: promote/abort/undo/drain).

## Promotion gates (both, per env)

| Env | `autoPromotionEnabled` | Behaviour |
|-----|------------------------|-----------|
| dev | `true` | Auto-promote once smoke passes (automated gate). |
| staging | `true` | Auto-promote once smoke passes; post-promotion re-smoke. |
| prod | `false` | Pause after smoke passes; **human** `kubectl argo rollouts promote` (manual gate). |

Argo CD still auto-syncs prod (so the preview color is created on a new image), but traffic does not shift until the manual promote — the analysis gate runs in all envs regardless.

## Tests-first gate — `.github/workflows/argocd-ci.yml`

On any `deploy/argocd/**` change: `kubeconform -strict` of every Argo CD manifest against the Argo CRD schemas, plus assertions that dev/staging auto-promote, prod is manual, and the analysis gate is on in every env.

## Acceptance (verified locally — Helm v4.2.0, kubeconform v0.8.0)

- All 6 Argo CD manifests **kubeconform-valid** (AppProject, root app-of-apps, argo-rollouts, 3 seqtoid-web Applications), incl. the multi-source `sources` field.
- **Cross-repo integration**: rendering the actual `seqtoid-web` chart against each env values file is valid — dev 5/5 (autoPromotion true), staging 6/6 (true), prod 6/6 (false). Confirms the values are chart-compatible and the gates are wired correctly.

## Out of scope / Bucket B

Live EKS cluster, installing Argo CD, ALB/ingress in front of the active Service, real ECR repos / IRSA role ARNs / account IDs (placeholders here), and the first live cutover off the legacy ECS/Happy path. Prometheus-backed analysis lands with the observability slice (9).
