# State-migration blocks — mirror of dev/staging, kept for parity and as safe
# insurance. In Terraform a `moved` block whose `from` address is absent from
# state is a no-op, so these can never cause a destroy; a MISSING block could.
#
# DIVERGENCE FROM dev/staging (deliberate): the itars "Lift access-management
# into a github-actions-runner-permissions module" change (2f48a32) wrapped dev
# and staging but did NOT wrap prod — prod retained its flat, root-level
# github-actions-runner-permissions.tf (its main.tf was left empty upstream).
# So prod's applied state is expected to ALREADY be at the root addresses these
# blocks target, making each block a no-op. They are retained anyway so that if
# any prod apply ever ran through the wrapper form, the migration is still a
# clean state MOVE rather than a destroy/recreate of the shared OIDC provider,
# the czid_ci_cd policy, or the executor role. Confirm against a reviewed
# `terraform plan` before the (separately-approved, HELD) prod apply.
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
