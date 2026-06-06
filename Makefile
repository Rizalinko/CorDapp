# AcmeCorp Corda Platform.
# Every target is safe to run locally. Targets that need a tool which is not
# installed print a hint and skip rather than failing the whole run.

SHELL := bash
.DEFAULT_GOAL := help

# image coordinates (overridable)
REGISTRY      ?= ghcr.io/acmecorp
CORDA_VERSION ?= 4.14
IMAGE_TAG     ?= $(CORDA_VERSION)-dev
JAR_IMAGE     ?= corda-jar:local
NODE_IMAGE    ?= corda-node:local

.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "\nUsage: make <target>\n\n"} \
	     /^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2} \
	     /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5)}' $(MAKEFILE_LIST)
	@echo

##@ Validation (local, no daemon required)

.PHONY: lint
lint: lint-shell lint-yaml lint-docker lint-actions ## Run all static checks that apply to the current tree

.PHONY: lint-shell
lint-shell: ## ShellCheck all shell scripts
	@command -v shellcheck >/dev/null || { echo "skip: shellcheck not installed"; exit 0; }
	@files=$$(git ls-files --cached --others --exclude-standard '*.sh' '*.bash' 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint-shell: no shell scripts yet"; else \
	  echo "shellcheck $$files"; shellcheck $$files; fi

.PHONY: lint-yaml
lint-yaml: ## Validate that all YAML parses
	@command -v yq >/dev/null || { echo "skip: yq not installed"; exit 0; }
	@files=$$(git ls-files --cached --others --exclude-standard '*.yml' '*.yaml' 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint-yaml: no YAML yet"; else \
	  for f in $$files; do yq -e 'true' "$$f" >/dev/null || { echo "INVALID: $$f"; exit 1; }; done; \
	  echo "lint-yaml: OK ($$(echo $$files | wc -w) files)"; fi

.PHONY: lint-docker
lint-docker: ## hadolint all Dockerfiles
	@command -v hadolint >/dev/null || { echo "skip: hadolint not installed"; exit 0; }
	@for f in $$(git ls-files --cached --others --exclude-standard '**/Dockerfile' 'Dockerfile'); do echo "hadolint $$f"; hadolint "$$f"; done
	@echo "lint-docker: OK"

.PHONY: lint-actions
lint-actions: ## actionlint all GitHub workflow files
	@command -v actionlint >/dev/null || { echo "skip: actionlint not installed"; exit 0; }
	@files=$$(git ls-files --cached --others --exclude-standard '.github/workflows/*.yml' '.github/workflows/*.yaml' 2>/dev/null); \
	if [ -z "$$files" ]; then echo "lint-actions: no workflows yet"; else actionlint $$files && echo "lint-actions: OK"; fi

##@ Container images (Part 1 — needs Docker)

.PHONY: build-jar
build-jar: ## Build the jar-image (certified JRE + Corda jars)
	docker build -t $(JAR_IMAGE) docker/jar-image

.PHONY: build-node
build-node: build-jar ## Build the node-image (FROM jar-image)
	docker build -t $(NODE_IMAGE) --build-arg JAR_IMAGE=$(JAR_IMAGE) docker/node-image

.PHONY: images
images: build-node ## Build all images

##@ Local network (Part 1 — needs Docker + compose)

.PHONY: network-up
network-up: images ## Build images, bootstrap, and start the local 3-node network
	NODE_IMAGE=$(NODE_IMAGE) docker compose up -d
	@echo "Network starting. Watch readiness with: make network-status"

.PHONY: network-status
network-status: ## Show health/status of each service
	docker compose ps

.PHONY: network-wait
network-wait: ## Block until notary + node1 + node2 are healthy
	TIMEOUT=$(or $(TIMEOUT),600) ./scripts/wait-healthy.sh notary node1 node2

.PHONY: network-logs
network-logs: ## Tail logs from all services
	docker compose logs -f

.PHONY: network-down
network-down: ## Stop the network and delete all volumes (full reset)
	docker compose down -v
