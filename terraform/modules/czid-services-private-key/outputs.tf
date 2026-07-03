# SEC-1 (CZID-42): the module no longer generates the key in Terraform, so the private/public key
# PEM outputs are gone — no key material is emitted or stored in state. Only non-sensitive Secrets
# Manager metadata is exported (nothing cross-stack consumed the old key outputs; grep 2026-07-03).

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the (out-of-band-provisioned) services private key."
  value       = aws_secretsmanager_secret.services_private_key_pem.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret holding the services private key."
  value       = aws_secretsmanager_secret.services_private_key_pem.name
}
