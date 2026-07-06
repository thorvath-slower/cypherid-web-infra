# Argo CD bootstrap

One-time setup to bring up GitOps blue/green delivery on an EKS cluster. After
this, the **app layer** is managed by the per-env app-of-apps root (`root-app.yaml`)
— you change app deployments by committing to this repo, not by running `kubectl`.

## Ownership model (#493)

- **Terraform = infra addons (SSOT).** The eks module installs LBC, argo-rollouts,
  cert-manager, external-dns, karpenter, efs-csi, metrics-server as Helm releases.
  Argo does **not** manage these — their reference manifests live in
  [`../_terraform-owned/`](../_terraform-owned/README.md) and are never synced.
- **Argo = app layer, per env.** The dev root manages only `apps/dev/`
  (`seqtoid-web-dev`). staging/prod are separate clusters with their own roots over
  `apps/{staging,prod}/`. This is cluster-per-env, not one cluster with env-namespaces.
- **Deliberate apps** (sigstore #77, the Node backend) live in
  [`../_deliberate/`](../_deliberate/README.md) and are applied by hand, never by a root.

## Bring-up

> Prereqs: an EKS cluster from the foundation `eks` module (which also installs the
> infra addons above), `kubectl` pointed at it, and `helm`.

```sh
# 1. Install Argo CD itself (pinned). server.insecure=true terminates TLS at the
#    ALB, not the argocd-server pod; --wait blocks until it's up.
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace --version 10.1.1 \
  --set configs.params."server\.insecure"=true --wait

# 2. Create the AppProject that scopes what CZ ID may deploy.
kubectl apply -f deploy/argocd/projects/czid.yaml

# 3. Apply the DEV app-of-apps root (see the staged-adoption runbook below).
kubectl apply -f deploy/argocd/bootstrap/root-app.yaml
```

Argo CD chart `10.1.1` / app v3.4.4 is pinned; Argo Rollouts (`2.41.0`) is a
Terraform-owned addon (see `../_terraform-owned/`). Day-2 ops (promote, rollback,
drain) are in [`../../RUNBOOK.md`](../../RUNBOOK.md).

## Staged-adoption runbook (step 3, in detail)

`root-app.yaml` is `czid-root-dev`: it manages only `apps/dev/`, and ships with
`prune: false` / `selfHeal: false` so adopting an already-running cluster is safe.

1. **Apply the root.** `seqtoid-web-dev` is typically already running (registered
   directly during bring-up). `czid-root-dev` adopts it; because the git spec
   matches the running app, the first sync is a **no-op**.
2. **Verify the adoption is clean** before trusting automation:
   ```sh
   kubectl -n argocd get application czid-root-dev seqtoid-web-dev
   # both Synced/Healthy; confirm the diff is empty:
   argocd app diff seqtoid-web-dev        # (or the Argo UI) — expect NO changes
   ```
   If the diff shows unexpected changes, stop and reconcile the git manifest to
   reality before proceeding — do **not** enable prune/selfHeal on a dirty diff.
3. **Enable automation** once the diff is clean: set `prune: true` and
   `selfHeal: true` in `root-app.yaml`, commit, and let it sync. From here the dev
   app layer is fully GitOps-managed.

## Adding things later

- **A new dev app:** drop its Application manifest in `apps/dev/` — the root picks
  it up. Keep infra addons in Terraform, not here.
- **staging/prod:** stand up that env's cluster + Argo, repoint
  `apps/{staging,prod}/*.yaml` `destination.server` at that cluster (they currently
  point at `kubernetes.default.svc` — see #493), and apply a matching per-env root.
- **A deliberate app** (sigstore, Node backend): follow [`../_deliberate/README.md`](../_deliberate/README.md).
