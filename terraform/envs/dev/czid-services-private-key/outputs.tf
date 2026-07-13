# SEC-1 (CZID-42): the private/public key PEM outputs are removed — no key material leaves the
# module or lands in state. The key is provisioned out of band; only non-sensitive Secrets Manager
# metadata is exported. Nothing cross-stack consumed the old key outputs (grep 2026-07-03).

output "secret_arn" {
  value     = module.czid-services-private-key.secret_arn
  sensitive = false
}

output "secret_name" {
  value     = module.czid-services-private-key.secret_name
  sensitive = false
}
