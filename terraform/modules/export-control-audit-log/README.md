# `export-control-audit-log` — CZID-331

The **immutable, retained evidence store** for the export-control program. Every access decision (WAF verdicts
+ the Layer-2 edge Lambda's per-request decisions) is the compliance proof that the controls operated; this is
where it lives, tamper-proof.

**Authored, NOT applied** (bucket-b). Standing it up + repointing the WAF logs at it is a **destructive
migration** of the existing log bucket — read the apply notes below.

## What it creates

- An S3 bucket with **Object Lock in COMPLIANCE mode** + versioning → objects can't be deleted or altered
  within the retention window, **not even by root**. (Object Lock is creation-time only, which is why this is a
  dedicated bucket — the cztack module the WAF currently uses can't enable it.)
- Default retention = `var.retention_days` (**counsel-owned** record-keeping period).
- SSE (KMS if `kms_key_arn` set, else AES256), full public-access block, and a TLS-only bucket policy that also
  lets AWS log delivery write WAF logs (`aws-waf-logs-` name prefix, so WAF can deliver directly).
- Optional (`create_edge_log_firehose = true`): a Firehose delivery stream so the edge Lambda's CloudWatch
  decision logs can be centralized here.

## Usage

```hcl
module "export_control_audit_log" {
  source                   = "../../modules/export-control-audit-log"
  name                     = "seqtoid-${var.tags.env}-export-control"
  retention_days           = var.audit_log_retention_days # COUNSEL-OWNED (e.g. 1825 = 5yr); no default
  create_edge_log_firehose = true
  tags                     = var.tags
}
```

## Apply notes (bucket-b — destructive, sequenced)

1. **Stand up this bucket** in the target account (non-destructive on its own).
2. **Repoint WAF logging** (`aws_wafv2_web_acl_logging_configuration` in the web-acl module) from the old cztack
   bucket to `module.export_control_audit_log.bucket_id`. The old WAF-log bucket is then retired — this is the
   **destructive migration**; do it deliberately, per `EXPORT-CONTROL-BUCKET-B-OUTLINE.md`.
3. **Edge logs:** add a CloudWatch **subscription filter per edge-region** on the Lambda's log groups
   (`/aws/lambda/<region>.<fn>`) targeting `module.export_control_audit_log.firehose_arn`, so the per-request
   decisions land in the immutable store too.
4. **Retention:** set `retention_days` to the **counsel-confirmed** record-keeping period before enforcing —
   COMPLIANCE mode means it cannot be shortened afterward, so confirm the number first.

## Owned by counsel

The **retention period** balances export record-keeping (often ~5 years) against privacy-law caps on PII — that
balance, and what decision data is retained, are counsel's call (CZID-331/335). This module makes the store
immutable and retained; counsel sets *how long* and *what's kept*.
