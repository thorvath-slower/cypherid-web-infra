# Argo CD bootstrap

One-time setup to bring up GitOps blue/green delivery on an EKS cluster. After
this, everything is managed by the app-of-apps (`root-app.yaml`) — you add or
change deployments by committing to this repo, not by running `kubectl`.

> Prereqs (Bucket B — live env): an EKS cluster from the foundation `eks`
> module, `kubectl` pointed at it, and `helm`.

```sh
# 1. Install Argo CD itself (pinned).
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace --version 7.7.0

# 2. Create the AppProject that scopes what CZ ID may deploy.
kubectl apply -f deploy/argocd/projects/czid.yaml

# 3. Apply the app-of-apps root. From here Argo CD self-manages the
#    argo-rollouts controller and the per-env seqtoid-web Applications.
kubectl apply -f deploy/argocd/bootstrap/root-app.yaml

# 4. (Optional) the Rollouts kubectl plugin, for promote/abort/watch:
#    https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation
```

Argo CD versions here (Argo CD chart `7.7.0`, Argo Rollouts chart `2.39.0` in
`../apps/argo-rollouts.yaml`) are pinned; bump deliberately. Day-2 operations
(promote, rollback, drain) are in [`../../RUNBOOK.md`](../../RUNBOOK.md).
