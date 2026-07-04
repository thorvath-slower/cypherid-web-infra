# vpc-endpoints

VPC endpoints for the web-infra web/batch tiers (GA network hardening — CZID-353).
Mirror of the `cypherid-workflow-infra` `vpc-endpoints` module (CZID-352).

Creates:

- **S3 gateway endpoint** (free; route-table association, no ENI) — carries the bulk
  sample/report I/O off the NAT gateway and onto the AWS backbone.
- **Interface endpoints** (PrivateLink; one ENI per subnet/AZ, `private_dns_enabled = true`)
  for `ecr.api`, `ecr.dkr`, `logs`, `ssm`, `ssmmessages`, `ec2messages`, `sts`,
  `secretsmanager` — the control-plane / auth services the web + ECS/EKS tiers call.
- A **security group** allowing HTTPS (443) from the VPC CIDR only.

SSOT: instantiated once per env from each env's `cloud-env` stack, which owns the VPC
(`module.aws-env`) and supplies `vpc_id` / `vpc_cidr_block` / private subnets / route tables.
The empty `public` (no-VPC) stage never instantiates it, so it stays empty there.

Design: `VPC-ENDPOINTS-ARCHITECTURE-2026-06-29.md`.

## Inputs

| Name | Description |
|------|-------------|
| `deployment_environment` | Env name (dev/staging/prod/sandbox), used in resource `Name` tags. |
| `vpc_id` | VPC the endpoints attach to. |
| `vpc_cidr_block` | VPC CIDR; the interface-endpoint SG allows 443 from this range. |
| `subnet_ids` | Private subnet IDs (one per AZ) for the interface-endpoint ENIs. |
| `route_table_ids` | Route tables to associate the S3 gateway endpoint with. |
| `interface_endpoint_services` | Short service names for the interface endpoints (defaulted). |
| `tags` | Extra tags. |

## Outputs

- `s3_gateway_endpoint_id`
- `s3_gateway_endpoint_prefix_list_id` — usable to scope ECS/EKS SG egress to S3 later.
- `interface_endpoint_ids` — map of service name -> endpoint ID.
- `endpoints_security_group_id`
