variable "enable_visibility" {
  description = "Enable CloudWatch metrics and sampled requests for visibility_config. Default is false."
  type        = bool
  default     = false
}
variable "scope" {
  description = "Specifies whether this is for CLOUDFRONT or REGIONAL."
  type        = string
}

variable "blocked_country_codes" {
  description = "ISO-3166 country codes to geo-block. SINGLE SOURCE: export-control/blocked-jurisdictions.json (counsel-owned, CZID-322). The env stack passes it via jsondecode(file(...)); the Layer-2 Lambda reads the SAME file. Never hard-code the list here or in the Lambda. No default — wiring is required so the source is always explicit."
  type        = list(string)
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

