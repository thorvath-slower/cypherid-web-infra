# eks-ssm-bastion

SSM-managed bastion for reaching a **private** EKS API endpoint (CZID #322).

When the cluster's public API endpoint is disabled (`endpoint_public_access =
false`), operators and CI can no longer reach the control plane from the
internet. This module provisions a minimal, hardened jump host in a private
subnet that is reachable **only** through AWS Systems Manager Session Manager —
no SSH, no public IP, no inbound security-group rules:

```
aws ssm start-session --target <bastion_instance_id>
# then, on the bastion:
aws eks update-kubeconfig --name <cluster> && kubectl get nodes
```

**Deploy it together with the private-endpoint flip.** The consuming `eks` stack
gates both the bastion and `endpoint_public_access = false` on the same
`var.eks_endpoint_private` toggle, so you never end up with a private endpoint
and no way in (lockout).

This is a **control-plane** access path only. It has nothing to do with the app
data path — the internet-facing app ALB (AWS Load Balancer Controller, #321)
stays reachable regardless. Making the EKS API private does not affect end-user
ingress.

## Hardening
- Private subnet, `associate_public_ip_address = false`.
- Egress-only SG (443 out for SSM + EKS API); a single ingress rule is added to
  the cluster SG so the bastion can reach the API on 443.
- IMDSv2 required, encrypted gp3 root, detailed monitoring, EBS-optimized
  (satisfies CKV_AWS_79/8/126/135).

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `name` | Name prefix (typically the cluster name). | — |
| `vpc_id` | VPC for the bastion. | — |
| `subnet_id` | Private subnet (NAT egress required). | — |
| `cluster_security_group_id` | EKS control-plane SG (ingress rule added). | — |
| `instance_type` | Instance type. | `t3.micro` |
| `tags` | Tags. | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `bastion_instance_id` | Target for `aws ssm start-session`. |
| `bastion_security_group_id` | Bastion SG. |
| `bastion_iam_role_name` | Bastion instance-profile role. |
