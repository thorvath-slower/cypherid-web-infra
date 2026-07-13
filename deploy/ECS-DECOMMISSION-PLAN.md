# ECS Decommission Plan — retire the czecs path

**Ticket:** #330 · **Epic:** #319 · **Predecessor (must finish first):**
[`EKS-CUTOVER-RUNBOOK.md`](./EKS-CUTOVER-RUNBOOK.md) (#329) ·
**Plan of record:** `EKS-BLUEGREEN-CUTOVER-PLAN-2026-06-27.md` (workspace)

> **This is a plan document. Nothing here is executed by authoring it.** Execution
> is **blocked** until **prod has been stable on EKS** through the agreed soak
> window (the #329 prod exit criterion). Removing the ECS path is the step with
> **no fast rollback** once the services are deleted — treat §4 (point of no
> return) as a hard gate.

---

## 0. Precondition — the ONE gate

**Do not start until prod is stable on EKS.** Concretely, all of:

- [ ] prod public hostname resolves to the EKS ALB (per #329 §3.3).
- [ ] Full soak window elapsed with the #329 §4 checklist green throughout.
- [ ] No `abort`/`undo`/DNS-revert was needed during the soak.
- [ ] At least one real prod deploy has flowed **entirely** through the new GitOps
      + Rollouts path (build → tag bump → sync → blue/green → promote) with **zero**
      czecs involvement.
- [ ] The Node strangler status is understood: this plan retires the **Rails ECS**
      path. The Node backend is dev-only (#457 owns its staging/prod story) — it is
      **not** a reason to hold or to expand this teardown.

Until every box is checked, ECS stays warm as the #329 rollback target. This plan
is the *last* thing in the epic.

---

## 1. Inventory — what gets removed (the czecs surface)

All paths are in the **seqtoid-web** repo unless noted.

**A. ECS task-definition templates (root — the live czecs deploy inputs)**
- `czecs.json` (web)
- `czecs-resque.json` (4 worker services)
- `czecs-shoryuken.json` (SQS worker)
- `czecs-task-migrate.json` (run-task migration)

**B. Manual/one-off czecs task defs (`bin/manual_deploy_scripts/`)**
- `czecs.json`, `czecs-resque.json`, `czecs-shoryuken.json`,
  `czecs-task-create-admin.json`, `czecs-task-curl.json`,
  `czecs-task-curl-data.json`, `czecs-task-rails.json`, `czecs-task-rake.json`

**C. The czecs deploy driver**
- `bin/deploy` (calls `czecs register/upgrade/task`)
- `bin/deploy_automation/deploy_rev.sh` and the czecs-calling helpers in
  `bin/deploy_automation/` (`_shared_functions.sh`, `_global_vars.sh`, the
  release-cycle scripts) — **audit each**: keep the parts that are release
  bookkeeping (version tags, changelog), remove only the czecs register/upgrade
  calls. `bin/gitops_deploy` is the replacement path (keep).

**D. GitHub Actions workflows that invoke the czecs path**
- `.github/workflows/deploy.yml`, `deploy-promote.yml`,
  `reusable-deploy-workflow.yml`, `promote-to-env.yml`,
  `automate-release-and-deployment-cycle.yml`,
  `automated-staging-release-and-deployment.yml`
- **Audit, don't blanket-delete:** the *build* half (image build/push to ECR) is
  **retained** — EKS still pulls from ECR. Remove only the `ecs
  register-task-definition` / `update-service` / `run-task` steps. The GitOps
  advance/promote workflows (`gitops-advance-dev.yml`, `promote-image.yml`) are the
  replacement and stay.

**E. Live AWS resources (per env: dev, staging, prod — via console/CLI or the TF
that owns them)**
- ECS **services** (web + 4 resque + shoryuken) → scale to 0, then delete.
- ECS **task definitions** → deregister (kept as history; deletion optional).
- The ECS **ALB / target groups** fronting those services (once DNS points at the
  EKS ALB and no traffic remains).
- ECS **task roles** (replaced by the app IRSA role) → remove after services gone.
- The ECS **cluster** itself, if it hosted nothing but seqtoid-web.
- CloudWatch `awslogs` log groups (optional; retain for audit if policy requires).

**F. Docs / references**
- Update `README.md`, `DEVELOPMENT.md`, `MAINTENANCE.md` and any deploy docs that
  describe the czecs flow → point at the GitOps + Rollouts flow ([`RUNBOOK.md`](./RUNBOOK.md)).
- Remove the `EKS-CUTOVER-RUNBOOK.md` "ECS still serving" caveats once ECS is gone.

**Explicitly NOT removed** (shared, still used by EKS):
- ECR repos + images, Chamber/SSM params + Secrets Manager, RDS MySQL 8, S3
  buckets, SWIPE state machines, the SFN-notifications SQS/EventBridge wiring,
  Redis, OpenSearch. EKS consumes all of these.

---

## 2. Ordered teardown (reversible → irreversible)

Do it **per env in reverse cutover order is NOT required** — decommission all envs
only after **prod** is proven, but you may retire dev/staging ECS earlier if those
envs have soaked. Within an env, go **least-destructive first** so every early step
is reversible:

1. **Stop new ECS deploys (reversible).** Merge the workflow edits from §1.D that
   remove the czecs steps (retain build/push). Now nothing *re-creates* an ECS
   service. CI stays green (the argocd-ci + GitOps path is unaffected).
2. **Scale ECS services to 0 (reversible).** `aws ecs update-service --desired-count
   0` for web + workers. Traffic already on EKS (DNS flipped in #329), so this is a
   no-op for users. **Soak here** — this is the last trivially-reversible state
   (scale back up to revert). ← *recommended dwell point before §4.*
3. **Remove the czecs task-def templates + driver (reversible via git).** Delete
   §1.A/§1.B/§1.C files. Reversible from git history, but now the repo can no longer
   *express* an ECS deploy — a deliberate one-way-ish step at the code level.
4. **Delete the ECS services (point of no return — see §4).**
5. **Delete ECS ALB/target groups, task roles, cluster (irreversible infra).**
6. **Docs sweep (§1.F).**

---

## 3. Safety checks at each step

- **Before §2.1:** confirm a prod deploy has gone fully through GitOps (§0). Grep
  the repo for remaining czecs invocations so nothing still calls the path you're
  removing:
  ```sh
  grep -rniE 'czecs|register-task-definition|update-service|ecs run-task' \
    bin .github/workflows | grep -v gitops
  ```
- **Before §2.2 (scale to 0):** verify `curl https://<env-host>/health_check` is
  served by the **EKS** ALB (check the responding ALB, not just a 200), and error
  rate is at baseline.
- **Before §2.4 (delete services):** re-run the full #329 §4 checklist. Confirm the
  ECS services have had **desired-count 0 for the whole dwell window** with zero
  user impact. This is the gate in §4.
- **Before §2.5 (delete infra):** confirm no other workload uses the ALB/roles/
  cluster (they were seqtoid-web-only). Check Route 53 has **no** record still
  pointing at the ECS ALB.
- **Throughout:** never touch the §1 "NOT removed" shared resources.

---

## 4. Point of no return

**§2.4 — deleting the ECS services — is the point of no return.** Up to and
including §2.2 (scale to 0), rollback is: scale the ECS services back up + revert
the Route 53 record to the ECS ALB → you're back on ECS in minutes. Once the
services (and then §2.5 the ALB/roles/cluster) are **deleted**, the #329 fast
rollback is gone; recovery means re-provisioning ECS from IaC/git, not a flip.

**Gate for crossing §2.4:**
- [ ] prod on EKS for the full agreed post-cutover soak (well beyond #329's soak).
- [ ] ECS at desired-count 0 for the whole dwell window, zero user impact.
- [ ] Sign-off recorded on #330 (this is Tom's call — document before closing).

Cross it **one env at a time**, prod **last**.

---

## 5. Exit criteria

- No `czecs*` files, no czecs calls in `bin/` or workflows (the §3 grep is empty).
- No ECS services / task defs / ECS ALB / ECS task roles for seqtoid-web in any env.
- Deploy docs describe only the GitOps + Argo Rollouts flow.
- The shared data/infra plane (ECR/RDS/S3/SWIPE/SQS/Redis/OpenSearch/SSM) intact
  and serving EKS.
- Epic #319 closable; leave a closing comment on #330 (what removed, per-env dates,
  the sign-off) before marking Done.
