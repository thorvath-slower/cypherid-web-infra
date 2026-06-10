# CZ ID — web infrastructure (OpenTofu)

Infrastructure-as-code for the CZ ID stack, using [OpenTofu](https://opentofu.org).
The repo is divided into **accounts**, **environments** (`dev`, `staging`,
`sandbox`, `prod`, `public`) and **components**. Changes are applied at the
component level: `cd` into a component and run OpenTofu there.

> This repo was previously generated and orchestrated by `fogg` and run through
> Terraform Cloud/Enterprise. It now runs on plain OpenTofu with no fogg and no
> TFC/TFE — the `terraform.tf` in each component is the hand-maintained source of
> truth (see `specs/002-tofu-conversion/`).

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) — pinned in
  `.opentofu-version` (`brew install opentofu`, or use
  [`tenv`](https://github.com/tofuutils/tenv)).
- AWS CLI with an `idseq-<env>` profile in `~/.aws/config`.

## Setup credentials

One-time SSO config:
```bash
aws configure sso --profile idseq-<env>
```
Re-authenticate (every day or so):
```bash
aws sso login --profile idseq-<env>
export AWS_DEFAULT_PROFILE=idseq-<env>
```

## Working with a component

Each component is a self-contained OpenTofu root module; the S3 backend
(bucket/key/region/profile) is declared in its `terraform.tf`.

```bash
cd terraform/envs/<env>/<component>
tofu init        # one-time per checkout / on backend or provider change
tofu plan
tofu apply
```

Bootstrapping an environment is the same flow, starting from the account
stack then the components in dependency order, e.g.:
```bash
cd terraform/accounts/idseq-<env> && tofu apply && cd -
cd terraform/envs/<env>/iam-password-policy && tofu apply
# ... params-secrets, route53, czid-services-private-key, cloud-env,
#     idseq-s3-tar-writer, elb-access-logs, ..., eks, k8s-core, happy
```
Dependencies between components are expressed with
`data "terraform_remote_state"`, so OpenTofu reads upstream outputs directly.

## Repo-wide helpers

A thin `Makefile` wraps OpenTofu (no fogg):

```bash
make fmt          # tofu fmt -recursive across the tree
make fmt-check    # formatting check (also run in CI)
make validate     # init -backend=false + validate every stack
make plan  DIR=terraform/envs/dev/auth0
make apply DIR=terraform/envs/dev/auth0
```

CI (`.github/workflows/tofu_ci.yml`) runs `tofu fmt -check` + `tofu validate`
on each changed stack. There is no auto-apply; applies are deliberate.

## SSH

To configure your ssh access:
1. Make sure you have a GitHub SSH key. Otherwise follow instructions [here](https://wiki.czi.team/display/SI/Accessing+GitHub+chanzuckerberg+organization)
1. Make sure your ssh agent is running. You can run `ssh-add -L` to test it out.
1. Ask #help-infra to be added to the `idseq` SSH group (usually happens with the previous step).
1. [Install blessclient](https://github.com/chanzuckerberg/blessclient):
```
# TLDR If you're on a Mac:

# Make sure you have your GitHub key loaded to your ssh agent
ssh-add
# Test you are able to connect to GitHub
ssh -T git@github.com

# Install blessclient
brew tap chanzuckerberg/tap
# if you had the old version of blessclient then we need to unlink it first
brew unlink blessclient
brew install blessclient@1
blessclient import-config git@github.com:/chanzuckerberg/idseq-infra/blessconfig.yml
```
SSH, scp, rsync, etc as you normally would

## individual-attr instances
* To make a change to the on-call, comp-bio instances, make a change to the `amis/{on-call, comp-bio}/main.pkr.hcl` and run ```packer build amis/comp-bio/main.pkr.hcl``` or ```aws-oidc exec --profile idseq-prod-poweruser -- packer build amis/comp-bio/main.pkr.hcl```
