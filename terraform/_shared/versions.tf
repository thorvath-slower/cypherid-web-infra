# =============================================================================
# CZ ID stack — canonical OpenTofu version + provider constraints.
#
# THE single source of truth. This file is symlinked into every root stack as
# `versions.tf`. Bump a version here ONCE and every stack moves together — no
# drift, no per-stack edits. (Constitution Principle III: one source of truth.)
#
# Cost of the shared list: a stack resolves every provider named here even if it
# uses only some. That is intentional and free in practice — CI uses a provider
# plugin cache and the appliance ships a local provider mirror, so nothing is
# re-downloaded per stack. Reproducibility > a slightly longer first init.
#
# Licensing gate (Principle II): all providers below are MPL-2.0 except
# bwoznicki/assert (MIT). No BUSL/SSPL. See specs/002-tofu-conversion/decisions.
# =============================================================================
terraform {
  required_version = ">= 1.10" # >= 1.10 for native S3 state locking (use_lockfile)
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.100.0" }
    archive    = { source = "hashicorp/archive", version = "~> 2.0" }
    assert     = { source = "bwoznicki/assert", version = "0.0.1" }
    auth0      = { source = "auth0/auth0", version = "~> 1.48.0" }
    helm       = { source = "hashicorp/helm", version = "~> 2.17.0" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.19.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.1.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
    null       = { source = "hashicorp/null", version = "3.1.1" }
    okta-head  = { source = "okta/okta", version = "> 3.30" }
    random     = { source = "hashicorp/random", version = "~> 3.4" }
    tls        = { source = "hashicorp/tls", version = "~> 3.0" }
  }
}
