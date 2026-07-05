# Additive Karpenter subnet discovery for THIS cluster (czid-dev-eks-v2).
#
# The eks module's EC2NodeClass matches subnets via EITHER the generic
# `karpenter.sh/discovery = <cluster>` tag OR a per-cluster unique-key tag
# `karpenter.sh/discovery/<cluster> = <cluster>`. The shared dev subnets already carry
# the OLD cluster's generic tag (`karpenter.sh/discovery = czid-dev-eks`). To let THIS
# cluster's Karpenter discover the same subnets WITHOUT overwriting that (which would
# break the old cluster's autoscaling), we add only the per-cluster UNIQUE-KEY tag.
#
# `aws_ec2_tag` manages exactly one tag key on one resource, so this is strictly additive:
# it never reads or modifies the old cluster's `karpenter.sh/discovery` tag. Both clusters'
# Karpenter coexist in the shared VPC.
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each    = toset(local.subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery/${local.cluster_name}"
  value       = local.cluster_name
}
