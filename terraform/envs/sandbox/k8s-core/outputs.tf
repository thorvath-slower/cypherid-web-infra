output "additional_addons" {
  value     = module.k8s-core.additional_addons
  sensitive = true
}

output "default_namespace" {
  value     = module.k8s-core.default_namespace
  sensitive = false
}


