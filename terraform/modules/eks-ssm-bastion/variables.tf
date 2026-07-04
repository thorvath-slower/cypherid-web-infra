variable "name" {
  type        = string
  description = "Name prefix for the bastion resources (typically the cluster name)."
}

variable "vpc_id" {
  type        = string
  description = "VPC in which to place the bastion."
}

variable "subnet_id" {
  type        = string
  description = "PRIVATE subnet for the bastion (must have NAT egress to the SSM + EKS endpoints; no public IP is assigned)."
}

variable "cluster_security_group_id" {
  type        = string
  description = "EKS cluster (control-plane) security group ID — an ingress rule is added so the bastion can reach the API on 443."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Bastion instance type. t3.micro is ample for kubectl/SSM."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all bastion resources."
}
