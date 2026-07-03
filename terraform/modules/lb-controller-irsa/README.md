# lb-controller-irsa

Shared SSOT module (CZID #321). Creates the IRSA IAM role + policy that the
**AWS Load Balancer Controller** assumes to manage ALBs/target groups for app
Ingresses. One definition; every EKS env instantiates it with its own cluster
name + OIDC provider.

The controller itself is installed cluster-wide via GitOps — the Argo CD
Application at `deploy/argocd/apps/aws-load-balancer-controller.yaml`. After
`terraform apply` in a given env's `eks` stack, take the `lb_controller_role_arn`
output and fill it into that Application's `REPLACE_LBC_IAM_ROLE_ARN` placeholder
(per cluster/account at bootstrap).

## Usage

```hcl
module "lb_controller_irsa" {
  source = "../../../modules/lb-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks-cluster.cluster_oidc_issuer_url
  tags              = local.tags
}
```

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `cluster_name` | EKS cluster name (names the role/policy). | — |
| `oidc_provider_arn` | Cluster IAM OIDC provider ARN. | — |
| `oidc_issuer_url` | Cluster OIDC issuer URL (scopes the trust). | — |
| `service_account_namespace` | Controller SA namespace. | `kube-system` |
| `service_account_name` | Controller SA name. | `aws-load-balancer-controller` |
| `permissions_boundary_arn` | Optional permissions boundary. | `null` |
| `tags` | Tags for the role/policy. | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | Fill into the Argo CD LBC Application `REPLACE_LBC_IAM_ROLE_ARN`. |
| `role_name` | IAM role name. |
| `policy_arn` | LBC IAM policy ARN. |

## Vendored IAM policy

`iam-policy.json` is the canonical AWS Load Balancer Controller IAM policy,
matching controller **v2.8.x** (Helm chart `aws-load-balancer-controller`
`1.8.1`, the version pinned in the Argo CD Application). It is vendored in-tree
(Constitution Principle II/III: no registry pull, no network at init, one source
of truth). To re-vendor: replace the file from the pinned upstream release
`docs/install/iam_policy.json` for the matching controller version and bump this
note.
