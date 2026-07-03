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

  # CZID-330 fail-closed guard: the geo-block rule must never silently become a no-op. An empty list
  # would produce a geo_match_statement that blocks nothing (a fail-OPEN geo layer) — and AWS WAF also
  # rejects an empty country_codes. Rather than let that surface as a confusing apply error (or, worse,
  # a list that drifted to empty slipping through), fail the plan explicitly with the reason. The list
  # is counsel-owned; the ONLY correct way to change the geo layer is a deliberate, reviewed edit to
  # the SSOT JSON, never an empty file. Content is authoritatively checked by
  # tools/validate-blocked-jurisdictions.py (CZID-322); this is the last-line infra guard.
  validation {
    condition     = length(var.blocked_country_codes) > 0
    error_message = "CZID-330 fail-closed: blocked_country_codes must be non-empty. The export-control geo-block cannot be silently disabled by an empty list — change export-control/blocked-jurisdictions.json deliberately (counsel-owned) instead."
  }
  validation {
    condition     = alltrue([for c in var.blocked_country_codes : can(regex("^[A-Z]{2}$", c))])
    error_message = "CZID-330: each blocked country code must be an upper-case ISO-3166 alpha-2 code (e.g. \"IR\"). A malformed code would silently not match and fail open."
  }
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

