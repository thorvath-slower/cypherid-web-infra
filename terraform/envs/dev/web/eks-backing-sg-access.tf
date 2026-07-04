# =============================================================================
# EKS/Argo strangler (#319) — network wiring: let the seqtoid-web pods on
# czid-dev-eks reach the backing services (Redis / Aurora / OpenSearch). This is
# the next happy-gap: happy wired its workloads into these SGs; the Argo-deployed
# pods aren't in the allowlist, so Rails times out at boot (Redis::TimeoutError).
#
# Pods use the EKS cluster SG for egress. Add ingress on each backing-service SG
# allowing that SG on the service port. PURELY ADDITIVE — new ingress rules only;
# the ECS app's existing rules are untouched. Apply with `-target` (dev/web drift).
#
# (Uses data.aws_eks_cluster.dev_eks already declared in eks-irsa.tf.)
# =============================================================================

locals {
  eks_cluster_sg_id = data.aws_eks_cluster.dev_eks.vpc_config[0].cluster_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_redis" {
  security_group_id            = "sg-05ab081f5b46c44aa" # idseq-dev-redis
  referenced_security_group_id = local.eks_cluster_sg_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "czid-dev-eks pods to dev Redis (EKS/Argo strangler #319)"
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_aurora" {
  security_group_id            = "sg-0720247e9f75691e7" # idseq-dev-rds (Aurora)
  referenced_security_group_id = local.eks_cluster_sg_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "czid-dev-eks pods to dev Aurora MySQL (EKS/Argo strangler #319)"
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_opensearch" {
  security_group_id            = "sg-06bc0468ac9d18d18" # czid-dev-heatmap-es (OpenSearch)
  referenced_security_group_id = local.eks_cluster_sg_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "czid-dev-eks pods to dev OpenSearch (EKS/Argo strangler #319)"
}
