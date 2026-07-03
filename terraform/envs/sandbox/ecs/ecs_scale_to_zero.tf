# ---------------------------------------------------------------------------
# Non-prod scale-to-zero (CZID-292 / #248)
#
# Sandbox is a non-prod environment: idle overnight and on weekends. These
# scheduled ASG actions scale the ECS container-instance cluster to ZERO during
# the off-hours window (local.off_hour_utc .. local.on_hour_utc, defined in
# main.tf) and restore it to baseline on weekday mornings, eliminating idle EC2
# spend. Weekends stay at zero (the "up" action only fires Mon-Fri).
#
# NEVER applied to prod. The prod ECS cluster has no scale-to-zero schedule.
#
# This replaces the previously-broken off_hour_utc/on_hour_utc module args (the
# ecs-cluster-v2.4.0 module never declared them) with real, working schedules.
#
# APPLY HAZARD (ops decision, apply held): while scaled to zero, sandbox ECS
# services have no host capacity and sit in PENDING until the morning "up"
# action restores instances. Intended off-hours state for sandbox. Times are UTC.
# ---------------------------------------------------------------------------

locals {
  # Baseline instance floor to restore at on_hour (mirrors module min_servers).
  scale_to_zero_baseline = 1
}

resource "aws_autoscaling_schedule" "ecs-off-hours-down" {
  scheduled_action_name  = "ecs-off-hours-down-${var.env}"
  autoscaling_group_name = module.ecs-cluster.asg_name

  # Scale to zero every day at off_hour_utc (covers nights + into the weekend).
  min_size         = 0
  max_size         = 0
  desired_capacity = 0
  recurrence       = "0 ${local.off_hour_utc} * * *"
}

resource "aws_autoscaling_schedule" "ecs-off-hours-up" {
  scheduled_action_name  = "ecs-off-hours-up-${var.env}"
  autoscaling_group_name = module.ecs-cluster.asg_name

  # Restore baseline on weekday mornings only (Mon-Fri) so weekends stay at zero.
  min_size         = local.scale_to_zero_baseline
  max_size         = local.scale_to_zero_baseline + 1
  desired_capacity = local.scale_to_zero_baseline
  recurrence       = "0 ${local.on_hour_utc} * * 1-5"
}
