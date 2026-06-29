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
  default = "db.r6g.large"
}

variable "manage_db_subnet_group" {
  type    = bool
  default = false
}
