# EKS Cutover Runbook — dev → staging → prod (blue/green)

**Ticket:** #329 (env cutover) · **Epic:** #319 (ECS→EKS + Argo Rollouts) ·
**Companion:** [`ECS-DECOMMISSION-PLAN.md`](./ECS-DECOMMISSION-PLAN.md) (#330) ·
**Plan of record:** `EKS-BLUEGREEN-CUTOVER-PLAN-2026-06-27.md` (workspace) ·
**Day-2 driver guide:** [`RUNBOOK.md`](./RUNBOOK.md)

> **This is a procedure document. Nothing here is executed by authoring it.** The
> live cutover is **blocked** on the EKS control plane being bootstrapped
> (Phase 0, #321) and the `REPLACE_*` account/DNS/cert/subnet/role values being
> filled. Drive it by hand, per env, in order, only after each precondition is
> green.

---

## 0. Scope — what is being cut over

Two workloads move from ECS (czecs) to EKS, each an **Argo Rollouts blueGreen
Rollout** with a smoke-gated promotion:

| Workload | Chart | App | Cutover track |
|---|---|---|---|
| `seqtoid-web` (Rails) | `seqtoid-web/deploy/charts/seqtoid-web` | `apps/seqtoid-web-{dev,staging,prod}.yaml` | full dev→staging→prod (this runbook) |
| `seqtoid-node-backend` (NestJS strangler) | `seqtoid-web/deploy/charts/seqtoid-node-backend` | `apps/seqtoid-node-backend-dev.yaml` | **dev-only** until the strangler proves out (#457); its own **separate hostname**, never the public edge yet |

The Rails cutover is the traffic-bearing one. The Node backend rides the same EKS
substrate but stays a **dev-only strangler seam** (own internal host, shares the
same Aurora/S3/SWIPE/SQS) — do **not** flip staging/prod Node traffic here; that
is the full-cutover ticket #457.

Order is always **dev → staging → prod**, and **ECS is not decommissioned** until
prod has been stable on EKS for the soak window (see #330 for the point of no
return). Both paths run in parallel during each env's soak.

---

## 1. Preconditions (per env, all must be green before you start)

- [ ] **Phase 0 bootstrap done** (#321): EKS cluster reachable; Argo CD installed;
      `root-app` applied; the `argo-rollouts` + `aws-load-balancer-controller`
      Apps are `Synced/Healthy`; `REPLACE_LBC_IAM_ROLE_ARN` filled.
- [ ] **Env values filled** — no `REPLACE_*` left in
      `deploy/argocd/values/seqtoid-web/<env>.yaml` (account id, ECR repo, IRSA
      role ARN, DNS host, ACM cert, subnets).
- [ ] **App IRSA role applied** for this env (replaces the ECS web task role) with
      SSM/S3/SQS/STS/SecretsManager perms; role ARN in the values file.
- [ ] **Image published** to the env's ECR repo at an immutable `sha-<commit>` tag;
      `image.tag` in the values file points at it (GitOps advances this, #444).
- [ ] **Chart CI green** — `argocd-ci.yml` `chart` job passed (helm lint/template +
      kubeconform incl. Rollout/AnalysisTemplate CRDs) for this env's values.
- [ ] **Smoke gate wired** — the staging smoke gate (#307) hangs off the Rollout
      `prePromotionAnalysis`; `smoke.paths` covers `/health_check` + any critical
      read path you want gated.
- [ ] **DB reachable from pods** — RDS **MySQL 8** from the EKS pods (the committed
      DB direction; no in-cluster DB — `deploy/postgres/` is the appliance adapter
      only). Confirm SG/subnet routing from the node subnets to RDS.
- [ ] **Rollback rehearsed** — you know `kubectl argo rollouts abort` / `undo` and
      the DNS/ALB revert step below.

---

## 2. Cutover mechanism — how traffic actually moves

The cutover is **not** an in-place DNS repoint of one ALB. Each substrate has its
own ALB:

- **ECS path:** an externally-managed ALB → the ECS service target group.
- **EKS path:** the AWS Load Balancer Controller provisions an ALB from the
  chart's `Ingress` → the Rollout's **active** Service.

So the switch is a **DNS-level flip** at the env's hostname (Route 53) between the
two ALBs, done **after** the EKS side is proven healthy while ECS still serves.
Two-stage per env:

1. **Parallel run (no user traffic on EKS yet).** Deploy the chart to EKS. The ALB
   comes up with its own DNS name. Validate against the *ALB DNS name directly*
   (or a temporary `eks-<env>.czid...` host) — **the public hostname still points
   at ECS.** Run the full verification checklist (§4) against the EKS ALB.
2. **Flip.** Once EKS is proven, repoint the env's public Route 53 record
   (CNAME/alias) from the ECS ALB to the EKS ALB. Watch (§4). ECS stays warm and
   untouched for the soak so the flip is instantly reversible (revert the record).

Within the EKS side, the **blue/green** happens on every subsequent deploy via
Argo Rollouts (preview color → smoke AnalysisRun → promote → active), per
[`RUNBOOK.md`](./RUNBOOK.md). The **env→env** cutover is the DNS flip above.

---

## 3. Per-env procedure

Set `ENV`, `NS=czid-<env>`, `ROLLOUT=czid-<env>-seqtoid-web`.

### 3.1 dev (do first; also stand up the Node strangler seam here)

1. Deploy: Argo CD syncs `seqtoid-web-dev` (auto-sync on). Confirm the **PreSync
   migrate Job** ran (`rails db:migrate:with_data`) and the **taxon-load Job**
   (if enabled) completed, then the Rollout came up.
   ```sh
   kubectl -n $NS get jobs
   kubectl argo rollouts get rollout $ROLLOUT -n $NS --watch
   ```
2. **Parallel run:** validate the EKS ALB directly (§4) while dev ECS still serves.
   dev auto-promotes on smoke pass (`autoPromotionEnabled: true`).
3. **Flip** the dev hostname's Route 53 record ECS→EKS. Re-run §4 against the
   public host. Soak.
4. **Node strangler seam (dev-only):** Argo CD syncs `seqtoid-node-backend-dev` on
   its **own internal host** (`node-dev.czid.internal`, `scheme: internal`). This
   is **additive** — it takes only traffic you point at that host; it does **not**
   touch the Rails hostname. Give the Node worker its **own dev SFN-notifications
   SQS queue** (set `SFN_NOTIFICATIONS_QUEUE_ARN` in the node dev values) or pause
   dev Rails' Shoryuken so the two monitors don't race. Validate `/health_check`
   and one strangler slice; leave running for parity work (#456).

### 3.2 staging (only after dev is stable)

1. Deploy: sync `seqtoid-web-staging` (auto-sync, auto-promote true). Same
   Job→Rollout sequence as dev.
2. Wire the **staging smoke gate (#307)** to the Rollout AnalysisRun if not already
   (it should already be referenced via `prePromotionAnalysis`).
3. Parallel-run → validate (§4) → **flip** the staging hostname ECS→EKS → soak.
4. Do **not** deploy Node to staging (strangler is dev-only until #457).

### 3.3 prod (only after staging is stable; MANUAL gate)

1. Deploy: sync `seqtoid-web-prod`. `autoPromotionEnabled: false` → the Rollout
   **pauses** after the smoke AnalysisRun passes.
2. **Eyeball the preview color** (query the preview Service / preview ALB path),
   then promote by hand:
   ```sh
   kubectl argo rollouts promote czid-prod-seqtoid-web -n czid-prod
   ```
3. Parallel-run → validate (§4) → **flip** the prod hostname ECS→EKS → **extended
   soak** (this is the gate before #330 decommission).
4. Do **not** deploy Node to prod (strangler is dev-only until #457).

---

## 4. Verification checklist (run at parallel-run AND after each flip)

- [ ] `kubectl argo rollouts status $ROLLOUT -n $NS` → `Healthy`; active color is
      the new revision; preview scaled per `scaleDownDelaySeconds`.
- [ ] `/health_check` returns 200 on the (env) host.
- [ ] The smoke `AnalysisRun` for the promotion is `Successful`.
- [ ] **Migrations applied** — the PreSync Job is `Complete`, no pending migration.
- [ ] **Discovery loads** against the real env Aurora (samples/projects render).
- [ ] **A real upload → pipeline dispatch → report** round-trips (mNGS smoke).
- [ ] Workers healthy: resque ×4 + shoryuken Deployments `Available`; queues drain;
      no crash-loop. (Node track: the `-worker` Deployment consuming its **own** dev
      queue.)
- [ ] Logs flow to stdout → cluster logging (no dependence on the old `awslogs`).
- [ ] Error rate / latency at parity with the ECS baseline over the soak window.
- [ ] **ECS still healthy** (untouched) — the revert target is intact.

---

## 5. Rollback

**Before promotion (prod):** a failed smoke `AnalysisRun` auto-aborts the rollout;
you can also `kubectl argo rollouts abort $ROLLOUT -n $NS`. No user traffic moved.

**After promotion, before the DNS flip:** `kubectl argo rollouts undo $ROLLOUT -n
$NS` returns to the previous EKS revision (the old color may still be warm within
`scaleDownDelaySeconds`, so it's fast).

**After the DNS flip (the real cutover rollback):** repoint the env's Route 53
record back to the **ECS ALB**. ECS was never touched during the soak, so this is
an instant, full revert. Then investigate on EKS out of the traffic path. **Do not
start #330 decommission until you're past the point where you'd ever need this.**

**Data note:** the migration is forward-only and run as a PreSync hook. Both apps
write the *same* schema, so a rollback to ECS after a migration is safe **iff** the
migration was backward-compatible (the standard expand/contract rule) — keep
migrations additive across a cutover window.

---

## 6. Exit criteria (per env)

- Public hostname resolves to the EKS ALB; ECS ALB no longer receiving user
  traffic (but still warm).
- All §4 checks green across the soak window.
- No manual `abort`/`undo`/revert needed during soak.
- **prod only:** stable for the agreed soak → hand off to #330 (ECS decommission).
