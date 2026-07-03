// CZID-353 — instantiate the VPC endpoints module for the web-infra (dev) VPC.
// Design: VPC-ENDPOINTS-ARCHITECTURE-2026-06-29.md. Mirror of workflow-infra CZID-352.
//
// Lives in the cloud-env stack because that stack owns the VPC (module.aws-env). This is the
// per-env SSOT instantiation — identical across dev/staging/prod/sandbox, differing only by the
// module.aws-env outputs it reads. The empty public/no-VPC stage has no cloud-env config, so it
// never instantiates this and stays empty.
//
// Additive + in-place-safe: adding endpoints and the S3 gateway route-table associations does not
// replace the existing VPC, subnets, or any tier security group.
module "vpc-endpoints" {
  source = "../../../modules/vpc-endpoints"

  deployment_environment = local.env

  vpc_id         = module.aws-env.vpc_id
  vpc_cidr_block = module.aws-env.vpc_cidr_block

  # Interface-endpoint ENIs land in the private subnets (one per AZ) where the web/ECS/EKS
  # compute runs.
  subnet_ids = module.aws-env.private_subnets

  # Associate the S3 gateway endpoint with the route tables of the tiers that reach S3: the
  # private (compute), database, and public route tables.
  route_table_ids = concat(
    module.aws-env.private_route_table_ids,
    module.aws-env.database_route_table_ids,
    module.aws-env.public_route_table_ids,
  )
}
