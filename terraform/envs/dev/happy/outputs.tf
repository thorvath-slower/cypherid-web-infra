output "databases" {
  value     = module.happy.databases
  sensitive = true
}

output "integration_secret" {
  value     = module.happy.integration_secret
  sensitive = true
}

output "namespace" {
  value     = module.happy.namespace
  sensitive = false
}


