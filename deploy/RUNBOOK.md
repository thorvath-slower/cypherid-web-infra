# Blue/Green Delivery — Runbook

I wrote this so anyone on the team can drive a deploy, promote it, or roll it
back without having to reverse-engineer the manifests. It covers `seqtoid-web`
on EKS via Argo CD + Argo Rollouts (feature-#002).

## How a deploy flows

1. CI builds the image and advances the `image.tag` in
   `deploy/argocd/values/seqtoid-web/<env>.yaml` (a commit to this repo).
2. Argo CD syncs the change. Argo Rollouts brings up the **preview** color
   (the new version) alongside the live **active** color — no traffic shifts yet.
3. The **smoke `AnalysisRun`** runs against the preview color (`/health_check`
   plus any critical paths I add to `smoke.paths`). If it fails, the rollout
   **auto-aborts and rolls back** — the active color never changed.
4. **Promotion gate:**
   - **dev / staging** (`autoPromotionEnabled: true`): once smoke passes, Argo
     Rollouts promotes automatically.
   - **prod** (`autoPromotionEnabled: false`): the rollout **pauses** after
     smoke passes and waits for me to promote by hand.
5. On promotion, active traffic switches to the new color. The old color stays
   up for `scaleDownDelaySeconds` so in-flight requests drain, then scales down.

Both gates exist on purpose: the automated analysis gate always runs; the manual
human gate is what guards prod.

## Day-2 commands

I use the `kubectl argo rollouts` plugin. `ROLLOUT=czid-prod-seqtoid-web`,
`NS=czid-prod` (swap for the env).

```sh
# Watch a rollout live (shows the active/preview colors + AnalysisRun status)
kubectl argo rollouts get rollout $ROLLOUT -n $NS --watch

# Promote prod after I've eyeballed the preview color (the manual gate)
kubectl argo rollouts promote $ROLLOUT -n $NS

# Abort + roll back to the stable color right now
kubectl argo rollouts abort $ROLLOUT -n $NS

# Undo a promotion that already happened (roll back to the previous revision)
kubectl argo rollouts undo $ROLLOUT -n $NS
```

## Rollback story

- **Before promotion:** a failed smoke `AnalysisRun` aborts automatically; I can
  also `abort` manually. Nothing reached live traffic.
- **After promotion:** `undo` flips back to the previous revision; because of
  `scaleDownDelaySeconds` the previous color may still be warm, so the flip is
  fast. `abortScaleDownDelaySeconds` keeps the rolled-back-to color from
  disappearing out from under me.

## Graceful drain

Pods get a `preStop` sleep (`gracefulDrain.preStopSleepSeconds`) so the Service
endpoints deregister them before they stop accepting connections, and a
`terminationGracePeriodSeconds` budget to finish in-flight work. Combined with
`scaleDownDelaySeconds` on the old color, a promotion doesn't drop requests.

## What's still Bucket B

Standing up the EKS cluster, installing Argo CD (see
[`argocd/bootstrap/README.md`](argocd/bootstrap/README.md)), wiring the ALB/
ingress in front of the active Service, filling in the real ECR repos / IRSA
role ARNs / account IDs in the env values, and the first **live** blue/green
cutover off the legacy ECS/Happy path. Prometheus-backed analysis arrives with
the observability slice; until then the gate is the Job-based smoke test.
