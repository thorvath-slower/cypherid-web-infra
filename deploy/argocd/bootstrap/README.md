# Argo CD bootstrap

One-time setup to bring up GitOps blue/green delivery on an EKS cluster. After
this, everything is managed by the app-of-apps (`root-app.yaml`) — you add or
change deployments by committing to this repo, not by running `kubectl`.

> Prereqs (Bucket B — live env): an EKS cluster from the foundation `eks`
> module, `kubectl` pointed at it, and `helm`.

```sh
# 1. Install Argo CD itself (pinned). server.insecure=true terminates TLS at the
#    ALB, not the argocd-server pod; --wait blocks until it's up.
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace --version 10.1.1 \
  --set configs.params."server\.insecure"=true --wait

# 2. Create the AppProject that scopes what CZ ID may deploy.
kubectl apply -f deploy/argocd/projects/czid.yaml

# 3. Apply the app-of-apps root. From here Argo CD self-manages the
#    argo-rollouts controller and the per-env seqtoid-web Applications.
kubectl apply -f deploy/argocd/bootstrap/root-app.yaml

# 4. (Optional) the Rollouts kubectl plugin, for promote/abort/watch:
#    https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation
```

Argo CD versions here (Argo CD chart `10.1.1` / app v3.4.4, Argo Rollouts chart
`2.41.0` in `../apps/argo-rollouts.yaml`) are pinned; bump deliberately. Day-2
operations (promote, rollback, drain) are in [`../../RUNBOOK.md`](../../RUNBOOK.md).

> **Single-env clusters (e.g. the dev strangler `czid-dev-eks-v2`):** step 3's
> `root-app.yaml` recurses `deploy/argocd/apps/` — which includes the staging AND
> prod `seqtoid-web` Applications, all destined for `kubernetes.default.svc`. On a
> per-env cluster that would deploy the wrong envs. There, skip the root-app and
> register just that env's Application directly, e.g.
> `kubectl apply -f deploy/argocd/apps/seqtoid-web-dev.yaml`. The app-of-apps root
> is for a hub cluster that fans out to remote env clusters.
