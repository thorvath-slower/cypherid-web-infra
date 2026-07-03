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
  description = "ISO-3166-1 alpha-2 country codes to geo-block (CZID-323, #280). SINGLE SOURCE: export-control/blocked-jurisdictions.json (counsel-owned, CZID-322). The env stack passes it via jsondecode(file(...)); the Layer-2 edge Lambda reads the SAME file. Never hard-code the list here or in the Lambda. No default — wiring is required so the source is always explicit and fail-closed cannot silently reduce to an empty block set."
  type        = list(string)
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

