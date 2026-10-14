VAR_FILE := terraform.auth.tfvars
PLAN_FILE := tfplan

.DEFAULT_GOAL := help
.PHONY: help init fmt validate plan apply destroy output

help: ## Show available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

$(VAR_FILE):
	@echo "Missing $(VAR_FILE). Copy $(VAR_FILE).example and fill it in." >&2
	@exit 1

init: ## terraform init
	terraform init -input=false

fmt: ## terraform fmt
	terraform fmt -recursive

validate: init ## terraform validate
	terraform validate

plan: init $(VAR_FILE) ## terraform plan, saved to a plan file
	terraform plan -input=false -var-file=$(VAR_FILE) -out=$(PLAN_FILE)

apply: ## Apply the saved plan from `make plan`
	@test -f $(PLAN_FILE) || { echo "No $(PLAN_FILE). Run 'make plan' first." >&2; exit 1; }
	terraform apply -input=false $(PLAN_FILE)
	@rm -f $(PLAN_FILE)

destroy: init $(VAR_FILE) ## terraform destroy (asks for confirmation)
	terraform destroy -var-file=$(VAR_FILE)

output: ## Show terraform outputs
	terraform output
