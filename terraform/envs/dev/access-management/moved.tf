# State-migration blocks: a June-2026 apply stored these resources under a
# `module.github-actions-runner-permissions` wrapper; the code was later flattened
# to the root module. Without these, terraform destroys+recreates the shared OIDC
# provider, the czid_ci_cd policy, and the executor role. These make them clean
# state MOVES (no destroy) so the OIDC hardening (#69) applies as an in-place trust
# update + additive plan/apply roles.
moved {
  from = module.github-actions-runner-permissions.aws_iam_openid_connect_provider.github
  to   = aws_iam_openid_connect_provider.github
}
moved {
  from = module.github-actions-runner-permissions.aws_iam_policy.czid_ci_cd
  to   = aws_iam_policy.czid_ci_cd
}
moved {
  from = module.github-actions-runner-permissions.module.czid_web_private_gh_actions_executor
  to   = module.czid_web_private_gh_actions_executor
}
