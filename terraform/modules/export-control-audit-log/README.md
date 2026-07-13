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

## Separation of concerns — what goes here (and what doesn't)

This is the **dedicated export-control compliance store**, kept SEPARATE from the normal WAF/app log bucket (the
cztack `logs_bucket` in the web-acl module). The two have different governance **on purpose**:

| | Normal log bucket (existing) | This controlled store |
|---|---|---|
| Holds | general WAF security + app logs | export-control **decision evidence** only |
| Retention | operational | counsel-set record-keeping period (long) |
| Mutability | normal lifecycle | Object Lock COMPLIANCE (immutable) |
| Access | standard | restricted |

**Do not repoint all WAF/app logging here** — that would conflate normal operational logs into the compliance
regime (long, immutable retention + restricted access). Only export-control evidence flows here.

## What flows in (apply, bucket-b)

1. **Stand up this bucket** in the target account (non-destructive on its own; nothing migrates).
2. **Edge Lambda decisions (primary evidence):** add a CloudWatch **subscription filter per edge-region** on
   the Lambda's log groups (`/aws/lambda/<region>.<fn>`) → `module.export_control_audit_log.firehose_arn`, so
   each per-request geo/VPN/residential decision lands in the immutable store. The normal WAF/app logs stay in
   their existing bucket, untouched.
3. **(Optional) export-control WAF decisions:** if counsel requires the Layer-1 geo/anonymizer *blocks* retained
   immutably too, add a WAF logging stream filtered to those rules → this store (via Firehose). General WAF
   security logs still go to the normal bucket.
4. **Retention:** set `retention_days` to the **counsel-confirmed** record-keeping period before enforcing —
   COMPLIANCE mode can't be shortened afterward, so confirm the number first.

## Owned by counsel

The **retention period** balances export record-keeping (often ~5 years) against privacy-law caps on PII — that
balance, and what decision data is retained, are counsel's call (CZID-331/335). This module makes the store
immutable and retained; counsel sets *how long* and *what's kept*.
