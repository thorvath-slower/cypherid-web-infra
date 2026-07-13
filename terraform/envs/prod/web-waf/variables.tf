# variable "snowflake_external_ids" {
#   type        = list(string)
#   default     = []
#   description = "define this in the TFE workspace UI"
# }

# variable "snowflake_iam_principal" {
#   type        = string
#   default     = ""
#   description = "define this in the TFE workspace UI"
# }

# CZID-324 (#281): known-good corporate egress CIDRs to ALLOWlist ahead of the export-control
# geo-block + AnonymousIpList (false-positive tuning). Empty (default) = nothing exempted, fully
# fail-closed. Populate with counsel/IT-approved corporate egress ranges (e.g. ["203.0.113.0/24"]).
variable "corporate_allowlist_cidrs" {
  type        = list(string)
  description = "Known-good corporate egress CIDRs allowlisted ahead of the geo/anonymizer blocks (CZID-324). Empty = nothing exempted."
  default     = []
}
