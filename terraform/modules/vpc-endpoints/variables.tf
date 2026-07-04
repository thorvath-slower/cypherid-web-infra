// CZID-353 — VPC endpoints for the web-infra web/batch tiers.
// Design: VPC-ENDPOINTS-ARCHITECTURE-2026-06-29.md. This module keeps AWS-service traffic
// (S3, ECR, CloudWatch Logs, SSM, STS, Secrets Manager) on the AWS backbone instead of routing
// it out through the IGW/NAT and the public internet.

variable "deployment_environment" {
  type        = string
  description = "Deployment environment: (dev, staging, prod, sandbox). The caller instantiates this module only for real-VPC envs; the empty public/no-VPC stage never runs it."
}

variable "vpc_id" {
  type        = string
  description = "ID of the web-infra VPC (module.aws-env in the cloud-env stack) the endpoints attach to."
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of the web-infra VPC. The interface-endpoint security group allows 443 from this range so in-VPC clients (web/ECS/EKS tasks, bastion) can reach the endpoint ENIs."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (one per AZ) in which to place the interface-endpoint ENIs."
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route table IDs to associate the gateway (S3) endpoint with (private + database + public tiers that need S3)."
}

variable "interface_endpoint_services" {
  type        = list(string)
  description = "Short service names (the segment after com.amazonaws.<region>.) to create interface endpoints for."
  default = [
    "ecr.api",        // ECR image auth/metadata (ECS/EKS image pulls)
    "ecr.dkr",        // ECR docker registry (layer pulls; layer blobs still transit the S3 gateway endpoint)
    "logs",           // CloudWatch Logs delivery (ECS task/app logs)
    "ssm",            // SSM parameter reads (web tier reads /idseq-<env>-web/* params)
    "ssmmessages",    // SSM Session Manager channel (bastion + EKS nodes run amazon-ssm-agent)
    "ec2messages",    // SSM agent <-> EC2 messages control plane
    "sts",            // regional STS role assumption (web task role, ECR auth)
    "secretsmanager", // web task policy reads secrets via secretsmanager:GetSecretValue
  ]
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to created resources."
  default     = {}
}
