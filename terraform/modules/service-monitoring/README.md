# service-monitoring (CZID-157)

Baseline CloudWatch **alarms + a dashboard** for the web-infra core services:

| Service     | Alarms |
|-------------|--------|
| ECS         | CPU high, memory high, running-task-count low (per service) |
| Aurora RDS  | CPU high, connections high, replica lag high, free storage low |
| OpenSearch  | cluster status RED, JVM memory pressure high, free storage low |
| ALB         | 5xx high, target response time high, unhealthy hosts |
| Lambda      | errors, throttles (per function) |

## Design

- **SSOT module**, consumed by a per-env `monitoring` stack (`terraform/envs/{dev,staging,prod,sandbox}/monitoring`).
- **Each resource group self-disables** when its identifier input is empty, so an env only creates alarms for the services it actually runs. Fill identifiers per env as services come online — the stack is apply-safe from day one.
- **Alarm actions** fan out to `alarm_actions_sns_topic_arn` — a per-env **placeholder** for the shared alerts topic (czid-infra foundation `monitoring.tf`) or a web-infra-owned topic. When empty, alarms are still created but carry no actions, so applying before the topic exists is safe.
- **Thresholds** are conservative starting points, all overridable per env.

## Status

Authored, **not applied**. Wire real identifiers + the SNS topic ARN, then apply per env (mirror dev → staging → prod → sandbox).
