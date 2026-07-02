# otel-collector

AWS-native OpenTelemetry collector for the platform (#426). Runs the **ADOT** (AWS Distro
for OpenTelemetry) collector as a **gateway ECS/Fargate service** that receives OTLP from
the app, workers, and pipeline, and exports to **CloudWatch EMF metrics + X-Ray traces +
CloudWatch Logs**.

Design principle: **the app only ever speaks OTLP.** The AWS-native backend is a choice made
entirely in the collector's exporter config here — swapping to self-hosted Grafana LGTM or a
managed OTLP vendor later is an edit to this module, not to any app. See `OPENTEL-DESIGN`.

## What it creates
- CloudWatch log group `/{project}-{env}/otel-collector`
- SSM parameter `/{project}-{env}-otel/collector-config` (the rendered collector YAML)
- IAM execution role (image pull + logs + read the SSM config) and task role
  (`AWSDistroOpenTelemetryPolicy` — CloudWatch/X-Ray/logs)
- Security group allowing OTLP `4317`/`4318` from `app_ingress_cidrs`
- Cloud Map private DNS namespace `{env}.otel.internal` + `collector` service
- ADOT ECS task definition + Fargate service (config injected via `AOT_CONFIG_CONTENT`)

## How the app consumes it
Point the app/worker tasks at the collector via env:
```
OTEL_EXPORTER_OTLP_ENDPOINT = <module.otel.otlp_grpc_endpoint>   # collector.{env}.otel.internal:4317
```
and let the OTel SDK auto-instrument. Traces land in X-Ray, RED metrics in CloudWatch under
`seqtoid/{env}`, logs in CloudWatch.

## Notes
- **Mirror across envs** per the SSOT/parity rule — instantiate one `envs/{env}/otel` stack per env.
- Pin `collector_image` to a digest in the consumer for reproducibility (module default is `:latest`
  only so the module is usable standalone).
- The HIPAA/compliance dashboards (prod `dashboards` stack) migrate onto these CloudWatch/X-Ray signals.
