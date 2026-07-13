// CZID-353 — VPC endpoints for the web-infra web/batch tiers (GA network hardening).
// Design: VPC-ENDPOINTS-ARCHITECTURE-2026-06-29.md. Mirror of the workflow-infra module
// (cypherid-workflow-infra CZID-352) adapted to the web-infra cloud-env stack.
//
// Gateway endpoints (free) route S3 traffic via the route table (no ENI, no per-GB charge) —
// this carries the bulk sample/report I/O for the web + ECS/EKS compute tiers. Interface
// endpoints (PrivateLink ENIs, one per subnet/AZ) front the control-plane / auth services and
// resolve transparently for existing SDK/CLI calls via private_dns_enabled. Together they let the
// web/batch compute tiers reach AWS APIs without traversing the NAT gateway / public internet,
// cutting NAT cost and keeping traffic on the AWS backbone.
//
// DynamoDB gateway endpoint deliberately NOT created: the web-infra tiers do not use DynamoDB
// (grep across terraform/ found no aws_dynamodb usage). Add it here if/when a service starts
// using DynamoDB.

data "aws_region" "current" {}

locals {
  # e.g. com.amazonaws.us-west-2.s3
  service_prefix = "com.amazonaws.${data.aws_region.current.name}"
}

# --- Gateway endpoint: S3 (free; route-table association, no ENI) ---------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "${local.service_prefix}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, {
    Name = "idseq-${var.deployment_environment}-s3"
  })
}

# --- Security group for the interface endpoints ---------------------------------------------
# Allows HTTPS (443) from the VPC CIDR only, so in-VPC clients (web/ECS/EKS tasks, bastion) can
# reach the endpoint ENIs. No broad egress: a stateful return-path allowing 443 back to the VPC
# CIDR is sufficient for endpoint responses (avoids CKV_AWS_382 open-egress on this new SG).
resource "aws_security_group" "endpoints" {
  name        = "idseq-${var.deployment_environment}-vpce"
  description = "HTTPS from the VPC CIDR to the interface VPC endpoints (CZID-353)."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from within the VPC to the interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "HTTPS responses back into the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = merge(var.tags, {
    Name = "idseq-${var.deployment_environment}-vpce"
  })
}

# --- Interface endpoints (PrivateLink; one ENI per subnet/AZ) --------------------------------
# private_dns_enabled = true so the regional service DNS name resolves to these ENIs inside the
# VPC — existing SDK/CLI calls hit the endpoint transparently with no code or config change.
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoint_services)

  vpc_id              = var.vpc_id
  service_name        = "${local.service_prefix}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "idseq-${var.deployment_environment}-${each.key}"
  })
}
