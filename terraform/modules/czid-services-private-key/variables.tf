variable "env" {
  type = string
}

variable "secret_string_wo_placeholder" {
  type        = string
  description = <<-EOT
    One-time placeholder seeded into the Secrets Manager secret on create via the write-only
    `secret_string_wo` argument (never persisted to Terraform state). The real ECDSA P-384
    private key is provisioned OUT OF BAND after apply, e.g.:
      openssl ecparam -name secp384r1 -genkey -noout -out czid-private-key.pem
      aws secretsmanager put-secret-value --secret-id <env>/czid-services-private-key \
        --secret-string file://czid-private-key.pem
    Terraform ignores changes to the value thereafter (SEC-1 / CZID-42), so this placeholder is
    only ever the initial seed and is deliberately NOT a real key.
  EOT
  default     = "PLACEHOLDER-SET-OUT-OF-BAND-SEE-CZID-42"

  validation {
    condition     = !can(regex("(?i)BEGIN [A-Z ]*PRIVATE KEY", var.secret_string_wo_placeholder))
    error_message = "secret_string_wo_placeholder must not contain real private key material; provision the key out of band (CZID-42)."
  }
}
