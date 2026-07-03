output "gh_actions_executor_role" {
  value     = module.czid_web_private_gh_actions_executor.role
  sensitive = false
}

output "gh_actions_plan_role" {
  value     = module.czid_gh_actions_plan.role
  sensitive = false
}

output "gh_actions_apply_role" {
  value     = module.czid_gh_actions_apply.role
  sensitive = false
}
