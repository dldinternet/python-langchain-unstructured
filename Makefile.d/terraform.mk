ROOT_DIR ?= $(PWD)/..
TEMPLATED ?= yes
IS_MONOREPO ?= no
TF_LOG ?= error
IS_TERRAGRUNT ?= no
TERRA_CMD ?= export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; export TF_VAR_iac_version=$$(cat $(ROOT_DIR)/VERSION); terraform
include $(ROOT_DIR)/Makefile.d/python.mk

TERRAGRUNT_CMD ?= export TERRAGRUNT_ORIGINAL_DIR=$$PWD; terragrunt run-all --terragrunt-include-external-dependencies --terragrunt-non-interactive --terragrunt-parallelism=1 --terragrunt-download-dir=$${PWD}/.terragrunt
TERRAGRUNT_DOWNLOAD_DIR ?= $${PWD}/.terragrunt
TERRAFORM_CMD ?= terraform
ifeq ("$(IS_TERRAGRUNT)","yes")
	IS_TERRAGRUNT := yes
	TERRAGRUNT_OPTIONS ?= --terragrunt-log-level=warning --terragrunt-debug --terragrunt-non-interactive
	TERRA_CMD := export TERRAGRUNT_ORIGINAL_DIR=$$PWD; export AWS_PROFILE=$${AWS_PROFILE:-$(AWS_PROFILE)} ; export TF_VAR_iac_version=$$(cat $(ROOT_DIR)/VERSION); $(TERRAGRUNT_CMD)
else
	TERRAGRUNT_OPTIONS :=
endif

include $(ROOT_DIR)/Makefile.d/terraform-macros.mk

ifndef TERRAFORM_MK_INCLUDED
plan: # Calculate terraform.tfplan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) validate $(TERRAGRUNT_OPTIONS)
	@$(TERRA_CMD) plan $(TERRAGRUNT_OPTIONS) -out=terraform.tfplan

plan_ci: # Calculate terraform.tfplan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) validate $(TERRAGRUNT_OPTIONS)
	@$(TERRA_CMD) plan $(TERRAGRUNT_OPTIONS) -no-color -input=false -out=terraform.tfplan

apply: # Apply terraform plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) apply $(TERRAGRUNT_OPTIONS) "terraform.tfplan"

apply_ci: # Apply terraform plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) apply $(TERRAGRUNT_OPTIONS) -input=false -no-color "terraform.tfplan"

destroy: # Destroy terraform resources
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) destroy $(TERRAGRUNT_OPTIONS)

output: # Show the outputs
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) output $(TERRAGRUNT_OPTIONS)

refresh: # Refresh the state
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) refresh $(TERRAGRUNT_OPTIONS)

get: # Get the dependencies
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) get $(TERRAGRUNT_OPTIONS)

check: # Get the dependencies
	[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS) -check || $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS) -check -diff; }

validate: # Get the dependencies
	@$(TERRA_CMD) validate $(TERRAGRUNT_OPTIONS) -no-color

show: # Show the plan
	@$(USE_TERRA_WHICH)
	@$(TERRA_CMD) show $(TERRAGRUNT_OPTIONS) -no-color terraform.tfplan 2>/dev/null

summarize: # Summarize the plan
	@rm /tmp/$$(basename $$PWD)-before_show_hook.txt 2>/dev/null || true
	@make show 2>&1 | egrep -e '^(Plan:|No changes.)' 2>&1 >/tmp/$$(basename $$PWD)-show.txt || echo 'No plan? No terraform.tfplan? Try "make plan" first ...'
	@if [ -f /tmp/$$(basename $$PWD)-before_show_hook.txt ] ; then \
		while IFS= read -r line1 && IFS= read -r line2 <&3; do \
			echo "$$(basename $$line1):" ; \
			echo "$$line2" ; \
		done < "/tmp/$$(basename $$PWD)-before_show_hook.txt" 3< "/tmp/$$(basename $$PWD)-show.txt" ; \
	else \
		echo MIA /tmp/$$(basename $$PWD)-before_show_hook.txt ; \
		cat /tmp/$$(basename $$PWD)-show.txt ; \
	fi

# $(TERRAGRUNT_CMD) terragrunt-info 2>/dev/null | jq '.WorkingDir' | sed 's/"//g' | egrep -v $$PWD
working_dir: # Get the working directory
	@if [ "yes" == "$(IS_TERRAGRUNT)" ] ; then \
		if [ -f .terragrunt-working_dirs ] ; then \
		  cat .terragrunt-working_dirs | sort | uniq ; \
		else \
		   make init; \
			if [ -f .terragrunt-working_dirs ] ; then \
			  cat .terragrunt-working_dirs | sort | uniq ; \
			else \
			   echo "ERROR: No .terragrunt-working_dirs!"; \
			   exit 1; \
			fi ; \
		fi ; \
	else \
	  echo $$(realpath $$PWD) ; \
	fi

clean: # Delete all temporary files and folders
	@$(USE_TERRA_WHICH)
	@rm -fr .terragrunt .terragrunt-cache .terraform .terraform.lock.hcl *.lock.hcl || true
	@for tgm in terragrunt-module-*/; do \
		find $$tgm -name "terragrunt*" -exec rm {} \; 2>/dev/null || true ; \
	done ; \
	rm -fr ./terragrunt-module-*/terragrunt.hcl .terragrunt-working_dirs 2>/dev/null || true

debug_ecr: # Debug services module
	@$(USE_TERRA_WHICH)
	export TARGET=ecr-collection; $(DEBUG_SERVICE)

debug_services: # Debug services module
	@$(USE_TERRA_WHICH)
	@export TARGET=service; $(DEBUG_SERVICE)

debug_database: # Debug database module
	@$(USE_TERRA_WHICH)
	@export TARGET=database; $(DEBUG_SERVICE)

debug_applications: # Debug applications module
	@$(USE_TERRA_WHICH)
	@export TARGET=applications-environment; $(DEBUG_SERVICE)

ifeq ("$(TEMPLATED)","yes")
generate: templates # Generate the environment terraform code from templates. Enabled when TEMPLATED := yes

terraform: generate # Generate the environment terraform code from templates Enabled when TEMPLATED := yes

templates: python_init # Generate the Terraform code. Depends on Python Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@$(USE_TERRA_WHICH) ; \
	  $(EXPAND_TEMPLATES_TERRAFORM)
	@$(TERRAFORM_CMD) fmt
	@[ "yes" != "$(IS_TERRAGRUNT)" ] || terragrunt hclfmt
	@egrep -Hn -e '(tf_mod_aws_|tg_mod_aws_|version)' *.hcl 2>/dev/null || true
#	@echo "Run 'make fmt' to format terragrunt code also i.e. $$(ls *.hcl)"

terragrunt_conversion: # Perform a conversion of the terraform code to terragrunt
	@$(USE_TERRA_WHICH) ; \
	  $(CLEANUP_TEMPLATES_TERRAFORM)

terragrunt_options: # Suggest some terragrunt options for development
	@$(USE_TERRA_WHICH) ; \
	  [ ! -z "$$TERRAGRUNT_OPTIONS" ] && echo "TERRAGRUNT_OPTIONS='$$TERRAGRUNT_OPTIONS'" || cat $(ROOT_DIR)/Makefile.d/terragrunt-options.txt

backend: python_init # Generate the Terraform backend and provider for all accounts. Depends on Python. Enabled when TEMPLATED := yes
	@echo TEMPLATED=$(TEMPLATED)
	@if [ "$(IS_TERRAGRUNT)" == "no" ] ; then \
  		$(EXPAND_TEMPLATES_BACKEND) ; \
	  else \
	    echo "Skipping terraform backend and provider generation for terragrunt" ; \
	  fi

init: get backend # Initialize the state and plugins
	@$(USE_TERRA_WHICH)
	@rm -fr ./terragrunt-module-*/terragrunt.hcl .terragrunt-working_dirs 2>/dev/null || true
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) init $(TERRAGRUNT_OPTIONS)
	@[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS); }
else
init: get # Initialize the state and plugins
	@$(USE_TERRA_WHICH)
	@export TF_REGISTRY_CLIENT_TIMEOUT=60; $(TERRA_CMD) init $(TERRAGRUNT_OPTIONS)
	@[ "yes" == "$(IS_TERRAGRUNT)" ] || { $(TERRA_CMD) fmt $(TERRAGRUNT_OPTIONS); }
endif

ifeq ("$(IS_MONOREPO)","yes")
docs: # Generate documentation
	@$(USE_MONOREPO)
	@for d in $(ROOT_DIR)/modules/*; do \
		if [ -z "$(basename $$d | grep '(__pycache__)' 2>&1)" ] ; then \
			echo $$d; \
			cd $$d; \
			make -C $$d docs; \
			cd $(ROOT_DIR); \
		fi ; \
	done

fmt: # Format terraform code
	@$(USE_MONOREPO)
	@for d in $(ROOT_DIR)/modules/*; do \
		echo $$d; \
		cd $$d; \
		make -C $$d fmt; \
		cd $(ROOT_DIR); \
	done
else
docs: fmt # Generate documentation
	@$(USE_CLASSICREPO)
	@$(TERRAFORM_DOCS_GENERATE)

fmt: # Format terraform code
	@$(USE_CLASSICREPO)
	@$(TERRAFORM_CMD) fmt
	@[ "yes" != "$(IS_TERRAGRUNT)" ] || { $(TERRAGRUNT_CMD) hclfmt || true; }
endif
TERRAFORM_MK_INCLUDED := yes
endif
