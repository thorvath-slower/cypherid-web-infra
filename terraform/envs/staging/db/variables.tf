variable "db_username" {
  default = "idseqmaster"
  type    = string
}

variable "db_port" {
  default = 3306
  type    = number
}

variable "db_instance_class" {
  type    = string
  default = "db.r6i.xlarge"
}

variable "manage_db_subnet_group" {
  type    = bool
  default = false
}

# CZID-351 (DATA-2): RDS storage-encryption key is IMMUTABLE — enabling a CMK on this LIVE cluster
# would REPLACE it (data loss). So false here: keep the AWS-managed key (kms_key_id null = no change).
# The live CMK migration is Bucket B. The rest of the DATA-2 hardening (monitoring/PI/backup/audit/
# log-exports) is additive/in-place and applies here.
variable "manage_db_kms_cmk" {
  type    = bool
  default = false
}
