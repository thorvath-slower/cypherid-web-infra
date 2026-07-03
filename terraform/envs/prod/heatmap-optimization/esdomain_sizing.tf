# ---------------------------------------------------------------------------
# OpenSearch (heatmap-es) sizing — SSOT per-env inputs (CZID-290 / #246)
#
# Sizing is intentionally per-env: prod carries real query load, non-prod is
# minimal. These variables make the sizing an explicit, reviewable SSOT input
# instead of a value hardcoded inline in esdomain.tf, so the count/type can be
# tuned per env without editing the module call.
#
# Prod right-size: 10 x m6g.xlarge (256 GB) -> 8 x m6g.large (350 GB).
#   - Fewer, smaller data nodes (halves per-node vCPU/RAM; 20% fewer nodes) to
#     cut the biggest fixed OpenSearch cost, while preserving cluster storage
#     headroom for the ~2.5 TB heatmap index (8 x 350 = 2800 GB > 2560 GB before).
#   - Count stays even for 2-AZ zone awareness (zone_awareness_config in module).
#
# APPLY HAZARD (ops decision, apply held): changing instance_type/count on a live
# OpenSearch domain triggers a blue/green domain update (in-place data migration,
# elevated resource use during the change). The final node count/type is an ops
# decision that MUST be validated against real index size + QPS from Cost
# Explorer / the OpenSearch console before apply. m6g.large adequacy under prod
# QPS in particular needs confirmation.
# ---------------------------------------------------------------------------

variable "es_instance_type" {
  description = "OpenSearch data-node instance type for the heatmap-es domain."
  type        = string
  default     = "m6g.large.elasticsearch"
}

variable "es_instance_count" {
  description = "OpenSearch data-node count for the heatmap-es domain. Keep even for 2-AZ zone awareness."
  type        = number
  default     = 8
}

variable "es_ebs_volume_type" {
  description = "EBS volume type for OpenSearch data nodes."
  type        = string
  default     = "gp3"
}

variable "es_ebs_volume_size" {
  description = "EBS volume size (GB) per OpenSearch data node."
  type        = number
  default     = 350
}
