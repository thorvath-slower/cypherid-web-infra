# `_deliberate/` — applied by hand, NEVER by a root app

These Argo `Application` manifests are intentionally **outside every root app's
path**. Each has a rollout that must be driven deliberately, so auto-sync is wrong.

## Contents

| File | Why it's deliberate |
|------|---------------------|
| `sigstore-policy-controller.yaml` + `sigstore-cosign-policy.yaml` | Cosign admission gate (#77). Installs a cluster-wide admission webhook. Follows a staged **warn → observe → enforce** rollout (see the PR that added it, #148). Auto-syncing it would skip the observation gate. Apply per its documented steps; it comes up in `mode: warn` with `failurePolicy: Ignore`. |
| `seqtoid-node-backend-dev.yaml` | The Node/NestJS backend strangler. Not yet deployed on dev. Apply deliberately when that slice is ready — not as a side effect of standing up the dev root. |

## To apply one (deliberately)

```
kubectl apply -f deploy/argocd/_deliberate/<app>.yaml      # creates the Application
# then sync + observe in the Argo UI / CLI per that app's rollout notes
```

Do not `git mv` these into `../apps/<env>/` unless you intend them to become
root-managed and auto-synced.
