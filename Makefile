ENV ?= uat
TF  := terraform

.PHONY: init fmt validate lint test plan apply destroy

init:
	$(TF) init -reconfigure -backend-config=envs/$(ENV).backend.hcl

fmt:
	$(TF) fmt -recursive

validate: init
	$(TF) validate

lint:
	tflint --recursive

test:
	@for m in modules/*; do if [ -d $$m/tests ]; then (cd $$m && $(TF) init -backend=false >/dev/null && $(TF) test) || exit 1; fi; done

plan: init
	$(TF) plan -var-file=envs/$(ENV).tfvars -out=$(ENV).tfplan

apply:
	$(TF) apply $(ENV).tfplan

destroy: init
	$(TF) destroy -var-file=envs/$(ENV).tfvars
