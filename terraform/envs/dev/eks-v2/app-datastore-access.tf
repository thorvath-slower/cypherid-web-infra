# =============================================================================
# App -> datastore network access for czid-dev-eks-v2.
#
# seqtoid-web pods egress via the cluster's NODE security group (worker SG), NOT
# the cluster control-plane SG. The app's datastores (Aurora, Redis, OpenSearch)
# live OUTSIDE the cluster and gate access by SG. So we add one ingress rule per
# datastore SG allowing the v2 node SG on the datastore's port — mirroring exactly
# what the OLD cluster's node SG (czid-dev-eks-node-sg) already has.
#
# ADDITIVE + coexisting: these are NEW ingress rules sourced from the v2 node SG;
# they neither touch nor remove the old cluster's rules. The live ECS app and the
# old EKS cluster keep their existing access. Drop these when the old cluster is
# decommissioned only if you also retire the v2 node SG (you won't — v2 becomes
# the dev cluster).
#
# The datastore SGs are looked up by name (stable) within the dev VPC. Ports match
# the discovered live rules: RDS 3306, Redis 6379, OpenSearch 443.
# =============================================================================

# The v2 cluster's node/worker SG (pods' egress identity).
locals {
  v2_node_sg = module.eks-cluster.worker_security_group
}

data "aws_security_group" "aurora" {
  vpc_id = local.vpc_id
  filter {
    name   = "group-name"
    values = ["idseq-dev-rds"] # Aurora MySQL 8 (idseq-dev)
  }
}

data "aws_security_group" "redis" {
  vpc_id = local.vpc_id
  filter {
    name   = "group-name"
    values = ["idseq-dev-redis-*"] # ElastiCache Redis (timestamp-suffixed name)
  }
}

data "aws_security_group" "opensearch" {
  vpc_id = local.vpc_id
  filter {
    name   = "group-name"
    values = ["czid-dev-heatmap-es-*"] # OpenSearch heatmap domain (timestamp-suffixed)
  }
}

resource "aws_security_group_rule" "v2_node_to_aurora" {
  description              = "seqtoid-web on czid-dev-eks-v2 to Aurora MySQL"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.aurora.id
  source_security_group_id = local.v2_node_sg
}

resource "aws_security_group_rule" "v2_node_to_redis" {
  description              = "seqtoid-web on czid-dev-eks-v2 to Redis"
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.redis.id
  source_security_group_id = local.v2_node_sg
}

resource "aws_security_group_rule" "v2_node_to_opensearch" {
  description              = "seqtoid-web on czid-dev-eks-v2 to OpenSearch"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = data.aws_security_group.opensearch.id
  source_security_group_id = local.v2_node_sg
}
