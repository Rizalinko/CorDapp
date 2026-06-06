# AcmeCorp Corda Platform — developer entry point.
# Every target is safe to run locally. Targets that need a tool which is not
# installed print a hint and skip rather than failing the whole run.

SHELL := bash
.DEFAULT_GOAL := help

# --- image coordinates (overridable) ---------------------------------------
REGISTRY      ?= ghcr.io/acmecorp
CORDA_VERSION ?= 4.14
IMAGE_TAG     ?= $(CORDA_VERSION)-dev

.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "\nUsage: make <target>\n\n"} \
	     /^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2} \
	     /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5)}' $(MAKEFILE_LIST)
	@echo

##@ Validation (local, no daemon required)

.PHONY: lint
lint: lint-shell lint-yaml ## Run all static checks that apply to the current tree

.PHONY: lint-shell
lint-shell: ## ShellCheck all shell scripts
	@command -v shellcheck >/dev/null || { echo "skip: shellcheck not installed"; exit 0; }
	@files=$$(git ls-files '*.sh' '*.bash' 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint-shell: no shell scripts yet"; else \
	  echo "shellcheck $$files"; shellcheck $$files; fi

.PHONY: lint-yaml
lint-yaml: ## Validate that all YAML parses
	@command -v yq >/dev/null || { echo "skip: yq not installed"; exit 0; }
	@files=$$(git ls-files '*.yml' '*.yaml' 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint-yaml: no YAML yet"; else \
	  for f in $$files; do yq -e 'true' "$$f" >/dev/null || { echo "INVALID: $$f"; exit 1; }; done; \
	  echo "lint-yaml: OK ($$(echo $$files | wc -w) files)"; fi
