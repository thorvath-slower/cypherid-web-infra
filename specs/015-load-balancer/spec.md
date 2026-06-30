# improvement-#015 — Load balancer (deploy-repo side)

Two-repo slice. This file covers the **cypherid-web-infra** half: install the AWS
Load Balancer Controller and turn on the public edge per environment. The Ingress
template itself lives in the seqtoid-web chart.

## Change
- New `deploy/argocd/apps/aws-load-balancer-controller.yaml` — Argo CD Application
  installing the `aws-load-balancer-controller` Helm chart (pinned `1.8.1`,
  `eks-charts`) into `kube-system`, mirroring the `argo-rollouts` app pattern
  (SSA, CreateNamespace, automated prune+selfHeal). IRSA role-arn, clusterName,
  and vpcId are `REPLACE_*` placeholders filled at bootstrap.
- `deploy/argocd/values/seqtoid-web/{dev,staging,prod}.yaml` — each gains an
  `ingress` block (`enabled: true`, env host, ACM `certificateArn`, public
  `subnets`), layered onto the chart's disabled-by-default ingress.
- `.github/workflows/argocd-ci.yml` — new assertion: the LB controller app exists
  and targets `kube-system`, and every env enables its ingress.

## Prerequisite (IaC, not GitOps — a follow-up item)
The controller needs an **IRSA IAM role** with the AWS Load Balancer Controller
policy. That role (and the ACM certs + public subnet tags
`kubernetes.io/role/elb`) are Terraform/Terraform work in the infra repos, not part
of this GitOps slice. Tracked as a follow-up; the placeholders mark where they plug in.

## Verification (local)
- `kubeconform -strict` over `projects/ bootstrap/ apps/`: **7/7 valid**, incl. the
  new LB controller Application.
- Cross-repo integration: rendered the seqtoid-web chart against each env's values
  and `kubeconform`'d — dev 6/6, staging 7/7, prod 7/7 valid; each renders exactly
  one Ingress whose backend is `czid-<env>-seqtoid-web-active:80`, with the HTTPS
  listener + ssl-redirect on the cert path.
- New argocd-ci assertions pass; `actionlint` clean.

## Bucket B
- Apply the IRSA role + cert/subnet tagging, sync the controller, provision the
  real ALBs, wire Route53, and run the first public cutover.

## Acceptance
- [x] LB controller installed via a pinned Argo CD Application.
- [x] Public edge enabled for dev/staging/prod with per-env cert + subnets.
- [x] Validates locally end-to-end (Argo manifests + cross-repo chart render).
- [x] Gate asserts the controller app + per-env ingress.
