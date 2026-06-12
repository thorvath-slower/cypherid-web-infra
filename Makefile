# CZ ID stack — native OpenTofu interface.
# fogg was removed in improvement-#002; this repo is plain OpenTofu now.
# Per-stack workflow is just `cd <stack> && tofu init && tofu plan`; the
# targets below add fmt/validate sweeps and thin init/plan/apply wrappers.

SHELL := /bin/bash -o pipefail
TOFU  ?= tofu

# Every leaf stack: any directory under terraform/ that contains *.tf,
# excluding the local .terraform working dirs and the _shared canonical files
# (terraform/_shared/versions.tf is symlinked into each stack, not a stack itself).
STACKS := $(shell find terraform -type f -name '*.tf' -not -path '*/.terraform/*' \
            -not -path '*/_shared/*' -exec dirname {} \; 2>/dev/null | sort -u)

.PHONY: help fmt fmt-check validate init plan apply

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

fmt: ## tofu fmt across the whole tree
	$(TOFU) fmt -recursive terraform

fmt-check: ## check formatting only (CI)
	$(TOFU) fmt -recursive -check terraform

validate: ## init -backend=false + validate every stack
	@set -e; for d in $(STACKS); do \
		echo "== $$d =="; \
		( cd "$$d" && $(TOFU) init -backend=false -input=false >/dev/null && $(TOFU) validate ); \
	done

# Single-stack wrappers. Usage: make plan DIR=terraform/envs/dev/auth0
DIR ?=
init: ## tofu init a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TOFU) init -input=false

plan: ## tofu plan a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TOFU) init -input=false >/dev/null && $(TOFU) plan -input=false

apply: ## tofu apply a single stack (DIR=...)
	@test -n "$(DIR)" || { echo "set DIR=<stack path>"; exit 1; }
	cd "$(DIR)" && $(TOFU) init -input=false >/dev/null && $(TOFU) apply -input=false
