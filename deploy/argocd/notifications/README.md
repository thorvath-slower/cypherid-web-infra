# Argo CD Notifications (#608)

Configures the `argocd-notifications-controller` (shipped with the argo-cd chart) to email
on-call when an Argo Application fails to sync or goes unhealthy.

## Why this exists

The controller was running with an **empty** `argocd-notifications-cm`, so failures alerted
nobody. That is the root cause of the #606 incident: a PreSync `db:migrate` hook wedged, the
sync sat in `Failed`/`Unknown`, and there was no rollout and **no alert**. These triggers
close that gap (`on-sync-failed` fires on `operationState.phase in [Error, Failed]` -- the
exact migrate-hook case).

## Ownership: hand-applied, not root-managed

Like [`../_terraform-owned/`](../_terraform-owned/README.md), this configures the Argo
**install**, not an app in the app layer. It is applied by hand, never by a root app:

```sh
kubectl apply -f deploy/argocd/notifications/argocd-notifications-cm.yaml
```

## Delivery creds (required for mail to actually send)

`argocd-notifications-cm`'s `service.email` references `$email-username` / `$email-password`
from the `argocd-notifications-secret`. That secret exists but is **empty** -- set the
SeqtoID-Support (M365) SMTP creds out-of-band (see `argocd-notifications-secret.example.yaml`):

```sh
kubectl -n argocd patch secret argocd-notifications-secret --type merge \
  -p '{"stringData":{"email-username":"SeqtoID-Support@ucsf.edu","email-password":"<m365-app-password>"}}'
```

Until then the triggers evaluate but mail cannot deliver.

## Files

| File | Purpose |
|------|---------|
| `argocd-notifications-cm.yaml` | Triggers, templates, email service, global subscription to `Thomas.Horvath@ucsf.edu`. |
| `argocd-notifications-secret.example.yaml` | Documents the secret keys. **Not** real creds; do not commit secrets. |

## Notes

- `context.argocdUrl` is intentionally empty until the Argo ingress (#609) lands; templates
  guard on it so no dead links render. Set it to the real UI URL once #609 is done.
- The subscription is **global** (in the CM), so it covers `seqtoid-web-dev` today and any
  staging/prod apps later with no per-app annotation.
