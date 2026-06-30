variable "name_prefix" {
  type        = string
  default     = "seqtoid"
  description = "Name prefix for the response-headers policy."
}

variable "env" {
  type        = string
  description = "Environment name (dev/staging/prod/sandbox)."
}

variable "hsts_max_age_sec" {
  type        = number
  default     = 31536000 # 1 year
  description = "HSTS max-age."
}

variable "hsts_include_subdomains" {
  type    = bool
  default = true
}

variable "hsts_preload" {
  type        = bool
  default     = false # preload is a deliberate, hard-to-undo browser-list submission
  description = "Whether to set the HSTS preload directive."
}

variable "frame_option" {
  type    = string
  default = "DENY"
}

variable "referrer_policy" {
  type    = string
  default = "strict-origin-when-cross-origin"
}
