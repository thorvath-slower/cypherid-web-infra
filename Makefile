# CZ ID stack — native Terraform interface.
# fogg was removed earlier; this repo is plain Terraform now.
# Per-stack workflow is just `cd <stack> && terraform init && terraform plan`; the
# targets below add fmt/validate sweeps and thin init/plan/apply wrappers.

SHELL := /bin/bash -o pipefail
TF    ?= terraform

# Every leaf stack: any directory under terraform/ that contains *.tf,
# excluding the local .terraform working dirs and the _shared canonical files
# (terraform/_shared/versions.tf is symlinked into each stack, not a stack itself).
STACKS := $(shell find terraform -type f -name '*.tf' -not -path '*/.terraform/*' \
            -not -path '*/_shared/*' -exec dirname {} \; 2>/dev/null | sort -u)

.PHONY: help fmt fmt-check validate init plan apply

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

fmt: ## terraform fmt across the whole tree
	$(TF) fmt -recursive terraform

fmt-check: ## check formatting only (CI)
	$(TF) fmt -recursive -check terraform

validate: ## init -backend=false + validate every stack
	@set -e; for d in $(STACKS); do \
		echo "== $$d =="; \
		( cd "$$d" && $(TF) init -backend=false -input=false >/dev/null && $(TF) validate ); \
	done

# Single-stack wrappers. Usage: make plan DIR=terraform/envs/dev/auth0
DIR ?=
init: ## terraform init a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TF) init -input=false

plan: ## terraform plan a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TF) init -input=false >/dev/null && $(TF) plan -input=false

apply: ## terraform apply a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TF) init -input=false >/dev/null && $(TF) apply -input=false
