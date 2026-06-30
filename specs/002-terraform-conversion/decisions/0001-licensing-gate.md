# ADR 0001 — Licensing gate for the Terraform conversion

**Status**: Accepted · **Date**: 2026-06-10 · **Slice**: `improvement-#002-terraform-conversion`

## Context

Constitution Principle II (NON-NEGOTIABLE) allows only MPL / Apache-2.0 / BSD / MIT in the shipped product, and the check runs at the `/speckit.plan` gate. Before converting `cypherid-web-infra` to Terraform I reviewed every provider and external module the repo depends on.

## Decision

We proceed. Nothing in the dependency set is BUSL/SSPL. The single Terraform Cloud/Enterprise dependency (`hashicorp/tfe`) is removed in this slice — not for its license (it is MPL-2.0) but because it is a single-vendor SaaS run platform and violates Principle I (Portability).

## Evidence

Providers in use (verified against upstream repos / Registry, 2026-06-10):

| Provider | License | Notes |
|---|---|---|
| `hashicorp/aws`, `tls`, `random`, `kubernetes`, `null`, `local`, `archive`, `helm`, `template` | MPL-2.0 | HashiCorp's BUSL change covers the *products* (Terraform, Vault, …), not the providers, which remain MPL-2.0. |
| `auth0/auth0` | MPL-2.0 | |
| `okta/okta` (`okta-head`) | MPL-2.0 | |
| `gavinbunney/kubectl` | MPL-2.0 | |
| `bwoznicki/assert` | MIT | |
| `hashicorp/tfe` | MPL-2.0 | **Removed** — TFC/TFE SaaS dependency (Principle I), not a license problem. |

External modules:

| Module source | License |
|---|---|
| `github.com/chanzuckerberg/cztack//*` | MIT |
| `cloudposse/terraform-aws-tfstate-backend` | Apache-2.0 |
| `terraform-aws-modules/security-group/aws` | Apache-2.0 |

## Consequences

- The engine itself moves from Terraform (BUSL-1.1) to **Terraform** (MPL-2.0), which is the reason this slice exists.
- The providers are pulled from the Terraform registry (`registry.terraform.io`), which mirrors all of the above.
- Re-run this gate whenever a provider or module is added (Governance clause: every plan run includes a Constitution Check).
