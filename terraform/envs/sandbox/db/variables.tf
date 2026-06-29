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
  default = "db.t3.medium"
}
