# EKS → Argo Blue/Green — Go-Live Checklist (CZID-319 / #22)

The master, top-to-bottom sequence for standing up the EKS + Argo CD + Argo Rollouts
blue/green platform and cutting each environment over from ECS. **Everything referenced here
is already authored and merged to `integration`** — this checklist is pure execution + config;
it introduces no new code.

Companion docs (do not duplicate — this checklist orders them):
- Per-env app cutover procedure → [`EKS-CUTOVER-RUNBOOK.md`](./EKS-CUTOVER-RUNBOOK.md) (CZID-329)
- ECS teardown after EKS serves → [`ECS-DECOMMISSION-PLAN.md`](./ECS-DECOMMISSION-PLAN.md) (CZID-330)
- Argo CD app-of-apps bootstrap → [`argocd/bootstrap/README.md`](./argocd/bootstrap/README.md)

**Scope guardrail:** the private-endpoint flip touches only the **control plane**; the internet-facing
app ingress (app ALB via the LB Controller) must stay reachable at every step, or a real user's
upload→process→result path breaks.

> Legend: ☐ = to do · 🔴 = needs a live `terraform apply` (Bucket B) · 🔑 = a GitHub secret/variable
> or AWS Console action **you** set (not code) · ▶ = a `kubectl`/`argocd`/`helm` op on the live cluster.

---

## Phase 0 — Prerequisites (before any apply)

- 🔑 ☐ **AWS accounts reachable** for the target env(s): dev `491013321714`, staging `030998640247`, prod `<prod acct>`. The OIDC deploy roles are authored for all three (`terraform/envs/{dev,staging,prod}/access-management/github-actions-runner-permissions.tf`); dev is already applied, staging/prod are not.
- 🔑 ☐ **GitHub secrets set** (I cannot set these — they're credentials):
  - `GITOPS_TOKEN` (#74) — lets CI write the image-tag bump to the GitOps values (the promotion flow).
  - `CHART_READ_TOKEN` (#327) — lets the chart-verification CI read the chart repo.
  - per-env `AWS_ACCOUNT_ID`, and `CI_ACCOUNT_ID` / `GHA_ROLE` (the fallbacks #360 wants to drop).
- 🔑 ☐ **Self-hosted runners** (#232/#39) exist and are ephemeral, **or** the workflows are repointed to GitHub-hosted. The deploy/lock workflows target self-hosted labels today.
- ☐ **ESO app merged** — External Secrets Operator (#325) is authored on a separate branch; merge it so pods can pull secrets before any workload runs.
- ☐ Confirm the private-cluster decision timing: the cluster starts with the **CIDR-restricted public** endpoint (from #55); the private flip (#322) is a later, separate step (Phase 4).

---

## Phase 1 — Stand up the cluster + control-plane (per env, dev first)

- 🔴 ☐ **Apply the EKS cluster** — `terraform apply terraform/envs/dev/eks` (vendored `aws-eks-cluster-v0.104.2`; Graviton `t4g` / AL2023_ARM_64 node groups; endpoint stays CIDR-restricted-public).
- 🔴 ☐ **Apply LB-Controller IRSA (#321)** — `lb-controller-irsa.tf` in the same stack emits `lb_controller_role_arn`.
- ▶ ☐ **Get kubeconfig** — `aws eks update-kubeconfig --name <cluster> --region us-west-2` and confirm `kubectl get nodes` shows the node group Ready.
- ✅ Verify: nodes Ready, `aws-node`/`kube-proxy` healthy, no NotReady alarms (the #364 EKS Container-Insights alarms + #157 core alarms fire once the addon is live).

---

## Phase 2 — Install Argo CD + the platform apps

- ▶ 🔑 ☐ **Bootstrap Argo CD** per [`argocd/bootstrap/README.md`](./argocd/bootstrap/README.md): `helm install` Argo CD into the cluster, then `kubectl apply -f deploy/argocd/bootstrap/root-app.yaml`.
- ▶ ☐ **Root app-of-apps syncs the platform** — Argo CD reconciles `deploy/argocd/apps/`:
  - `aws-load-balancer-controller.yaml` (fill `REPLACE_LBC_IAM_ROLE_ARN` / `REPLACE_CLUSTER_NAME` / `REPLACE_VPC_ID` from Phase 1 outputs)
  - `argo-rollouts.yaml` (the blue/green controller)
  - the ESO app (from #325)
  - `projects/czid.yaml` (AppProject allowlist — chart repos + `kube-system` destination)
- ✅ Verify: `argo-rollouts`, `aws-load-balancer-controller`, ESO all **Synced/Healthy** in Argo CD; the LB Controller can provision an ALB.

---

## Phase 3 — First live blue/green cutover: **dev** (CZID-22)

Follow [`EKS-CUTOVER-RUNBOOK.md`](./EKS-CUTOVER-RUNBOOK.md) for the detailed procedure. In short:
- ▶ ☐ Argo CD syncs `apps/seqtoid-web-dev.yaml` → the seqtoid-web **Rollout** (`deploy/charts/seqtoid-web/`, in the app repo) with active + preview services, the pre-sync **migrate Job** (sync-wave), and the **taxon-lineage load Job** (#471, sync-wave 1).
- ▶ ☐ The Rollout goes **preview → `prePromotionAnalysis` smoke AnalysisRun (#326)**. Do NOT promote until the AnalysisRun passes.
- ▶ ☐ **Promote** (`argo rollouts promote seqtoid-web`) → traffic shifts to the new version on the active service.
- 🔴 ☐ **DNS/ALB flip** — repoint the dev hostname from the ECS ALB to the EKS app ALB (parallel-run first, verify the full upload→process→result path, then Route 53 switch). Rollback = revert the Route 53 record (pre-flip) or `argo rollouts abort/undo` (during rollout).
- ✅ Verify against the runbook's checklist: login (Auth0), sample upload, a pipeline run, heatmap/report render, bulk download — the real user path end to end.

---

## Phase 4 — Promote the pattern: staging → prod (CZID-329)

- 🔴 🔑 ☐ **Repeat Phases 1–3 for staging**, then **prod** (each needs its account applied + its GitHub Environment).
- 🔑 ☐ **Create the staging/prod GitHub Environments with required-reviewer rules (#81/#96)** — the promotion approval gates in the #464 digest-promotion pipeline are inert until these exist; **prod never auto-promotes** (`autoPromotionEnabled: false` in the prod Rollout).
- ▶ ☐ Prod promotion is a **manual** `argo rollouts promote` after the human approval + the smoke AnalysisRun.

---

## Phase 5 — Harden: private control-plane endpoint (CZID-322)

- 🔴 ☐ **Flip only after SSM-bastion access is proven.** Set `eks_endpoint_private = true` in the env's `eks` stack (default is `false`); the module count-creates the SSM bastion **in lockstep** so there's no lockout.
- ✅ Verify: `kubectl`/Argo still reach the API via the bastion/in-VPC path; **the app ALB (public ingress) is unaffected** — confirm the user path still works.

---

## Phase 6 — Decommission ECS (CZID-330)

- 🔴 ☐ Only once EKS is serving all traffic for the env. Follow [`ECS-DECOMMISSION-PLAN.md`](./ECS-DECOMMISSION-PLAN.md): least-destructive-first ordering, per-step safety checks, and the explicit **point-of-no-return** (deleting the ECS services). Keep a parallel-run window before teardown.

---

## Parallel track — Node strangler (CZID-454)

The Node/NestJS backend is offline-complete on LocalStack; only the live deploy remains:
- 🔴 ☐ **#455** — apply the node-backend IRSA + deploy via `apps/seqtoid-node-backend-dev.yaml` (its Helm chart is `deploy/charts/seqtoid-node-backend/`).
- ▶ ☐ **#456** — run one mNGS sample end-to-end in dev on the Node path.
- ☐ **#457** — full cutover (staging/prod Node apps + the public-edge flip) — only after dev parity proves out. Stays dev-only until then.

---

## Still-open items this checklist depends on

| Item | What | Who |
|---|---|---|
| #74 | `GITOPS_TOKEN` secret | you (GitHub) |
| — | `CHART_READ_TOKEN` secret | you (GitHub) |
| #83 | repo/org secrets + variables inventory (per-env `AWS_ACCOUNT_ID`, `CI_ACCOUNT_ID`, `GHA_ROLE`) | you (GitHub) |
| #81/#96 | staging/prod GitHub Environments + reviewer rules | you (GitHub) |
| #232/#39 | self-hosted runners exist + ephemeral | ops |
| #325 | merge the ESO app | eng (mergeable now) |
| #77 | cosign verify-at-deploy admission gate | eng-authored, applies on-cluster |
| #79/#80/#81 | mirror the OIDC bootstrap apply to staging/prod | ops (TF authored, apply pending) |
| #367 | one-time manual prod bootstrap deploy | ops |

**Bottom line:** the platform is 100% authored. This checklist is gated only on **live AWS/the cluster**
and the **~5 GitHub secrets/Environments** above — no remaining application or infra code.
