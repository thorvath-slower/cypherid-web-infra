variable "db_username" {
  default = "idseqmaster"
  type    = string
}

variable "db_port" {
  default = 3306
  type    = number
}

# DATA-2 / #419: greenfield gate for the customer-managed RDS CMK. false on this LIVE env, so the
# aurora_hardening KMS key + local.db_kms_key_arn resolve to null (cluster keeps the AWS-managed key,
# no change). Mirrors dev/staging; declared so aurora_hardening.tf's local/count refs resolve.
variable "manage_db_kms_cmk" {
  type    = bool
  default = false
}
