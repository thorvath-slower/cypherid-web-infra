# Private key used to authenticate the user so they can use the GraphQL federated service & next-gen service.
# Generate the key material OUT OF BAND, never in Terraform, e.g.:
#   >> openssl ecparam -name secp384r1 -genkey -noout -out czid-private-key.pem
#
# SEC-1 (CZID-42): the key material must NOT be stored in Terraform state.
#
# Terraform owns only the Secrets Manager *container* (name, description, recovery window) and
# seeds a one-time placeholder version via the write-only `secret_string_wo` argument — a
# write-only value that Terraform never persists to state. The real private key is injected
# out of band (aws secretsmanager put-secret-value / console) and this resource ignores changes
# to the secret value so Terraform never reads it back, never diffs it, and never overwrites it.
#
# The previous `tls_private_key` resource generated the key inside Terraform, which landed the
# PEM in state (and re-exported it as an output). Both are removed. If we later want in-TF
# generation again without state exposure, adopt the ephemeral resource once the tls provider is
# bumped to >= 4.1 (a repo-wide shared versions.tf change, tracked separately):
#   ephemeral "tls_private_key" "ecdsa-p384" {
#     algorithm   = "ECDSA"
#     ecdsa_curve = "P384"
#   }
# and feed ephemeral.tls_private_key.ecdsa-p384.private_key_pem into secret_string_wo.

locals {
  secret_name    = "${var.env}/czid-services-private-key"
  rotate_version = "1" // Increment this to rotate the placeholder seed (real key rotates out of band)
}

resource "aws_secretsmanager_secret" "services_private_key_pem" {
  name        = local.secret_name
  description = "Private key used to authenticate the user so they can use the GraphQL federated service & next-gen service. Key material provisioned OUT OF BAND (never in TF state) >> openssl ecparam -name secp384r1 -genkey -noout -out czid-private-key.pem"
  # SEC-1 (CZID-42): keep a recovery window in shared/long-lived envs so an accidental destroy of this
  # services private key is recoverable. dev/sandbox keep 0 for frictionless teardown+rebuild (a deleted
  # secret name is otherwise locked for the recovery window, blocking immediate recreate).
  recovery_window_in_days = contains(["dev", "sandbox"], var.env) ? 0 : 7
}

resource "aws_secretsmanager_secret_version" "api_key_version" {
  secret_id = aws_secretsmanager_secret.services_private_key_pem.id
  # SEC-1 (CZID-42): a one-time write-only placeholder. `secret_string_wo` is never stored in state,
  # and the real key is put out of band, so no private key material ever lands in Terraform state.
  secret_string_wo         = var.secret_string_wo_placeholder
  secret_string_wo_version = local.rotate_version

  lifecycle {
    # The authoritative value is set out of band; do not let Terraform overwrite it back to the
    # placeholder or diff on the version once the real key is in place.
    ignore_changes = [secret_string_wo, secret_string_wo_version]
  }
}
