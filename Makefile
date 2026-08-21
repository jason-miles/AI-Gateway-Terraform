# Developer convenience wrapper. Run from terraform/.
# Usage: make validate | make plan VARS=/path/to.tfvars | make lint | make scan

TF ?= terraform
VARS ?= terraform.tfvars

.PHONY: fmt init validate plan apply lint scan check clean

fmt: ## Format all HCL
	$(TF) fmt -recursive

init: ## Init providers (no backend)
	$(TF) init -backend=false -input=false

validate: init ## Validate root config
	$(TF) validate

plan: ## Plan against a workspace (needs auth + VARS)
	$(TF) plan -var-file=$(VARS)

apply: ## Apply (needs auth + VARS)
	$(TF) apply -var-file=$(VARS)

lint: ## tflint (recursive)
	tflint --init && tflint --recursive --config="$(CURDIR)/.tflint.hcl"

scan: ## checkov security scan
	checkov -d . --framework terraform --quiet

check: validate lint scan ## Everything CI runs

clean: ## Remove local TF working files
	rm -rf .terraform .terraform.lock.hcl
