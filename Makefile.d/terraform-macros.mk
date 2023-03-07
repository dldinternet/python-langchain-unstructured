define SNAKE
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_snake " 🐍 "'
endef

define RUBY
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_ruby " 💎 "'
endef

define USE_TERRAFORM
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_terraform " Terraform -- $@ "'
endef

define USE_TERRAGRUNT
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; bg_terragrunt " Terragrunt -- $@ "'
endef

define USE_MONOREPO
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc; bg_monorepo " monorepo -- $@ "'
endef

define USE_CLASSICREPO
export SHELL="/bin/bash"; \
bash -c 'source $(ROOT_DIR)/cicd/rc/ansi-colors.rc; bg_classicrepo " classicrepo -- $@ "'
endef

BACKUP_MAKEFILE = cp Makefile Makefile.bak || true
RESTORE_MAKEFILE = [ -f Makefile.bak ] && { diff Makefile.bak Makefile 2>&1 >/dev/null; [ 0 -ne $$? ] || mv -f Makefile.bak Makefile; } || true

EXPAND_TEMPLATES_BACKEND = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$$(cat $(ROOT_DIR)/VERSION); \
for tpl in $(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/{backend,providers}.tf.jinja2; do \
	$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$$(dirname $$tpl)/.. -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || exit $$?; \
done

EXPAND_TEMPLATES_TERRAFORM = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$$(cat $(ROOT_DIR)/VERSION); \
$(BACKUP_MAKEFILE) ; \
for tpl in $(ROOT_DIR)/$(TERRAFORM_TEMPLATE)/*.jinja2; do \
	echo $$tpl ; \
	RC=0 ; \
	$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$$(dirname $$tpl)/.. -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || RC=$$?; \
	test 0 -eq $$RC || { $(RESTORE_MAKEFILE) ; exit $$RC; } ; \
done ; \
$(RESTORE_MAKEFILE)

EXPAND_TEMPLATES_TERRAGRUNT = export SHELL="/bin/bash"; \
export TF_VAR_iac_version=$$(cat $(ROOT_DIR)/VERSION); \
$(BACKUP_MAKEFILE) ; \
for tpl in $(ROOT_DIR)/$(TERRAGRUNT_TEMPLATE)/*.jinja2; do \
echo $$tpl ; \
RC=0 ; \
$(PYTHON) $(ROOT_DIR)/bin/template-expander.py -i $$tpl -o ./$$(basename $${tpl//.jinja2/}) -s .:$$(dirname $$tpl):$$(dirname $$tpl)/.. -d $(ROOT_DIR)/config/$(ENVIRONMENT_NAME).toml || RC=$$?; \
test 0 -eq $$RC || { $(RESTORE_MAKEFILE); exit $$RC; } ; \
done ; \
$(RESTORE_MAKEFILE)

USE_TERRA_WHICH = if [ "$(IS_TERRAGRUNT)" == "no" ] ; then \
	$(USE_TERRAFORM) ; \
else \
	$(USE_TERRAGRUNT) ; \
fi

CLEANUP_TEMPLATES_TERRAFORM = export SHELL="/bin/bash"; \
export PYTHON=$(PYTHON) ; \
export ROOT_DIR=$(ROOT_DIR) ; \
export TERRAFORM_TEMPLATE=$(TERRAFORM_TEMPLATE) ; \
export ENVIRONMENT_NAME=$(ENVIRONMENT_NAME) ; \
bash $(ROOT_DIR)/bin/terragrunt-conversion.sh

TERRAFORM_DOCS_GENERATE = export SHELL="/bin/bash"; \
export TERRAGRUNT_ORIGINAL_DIR=$$PWD; \
export ROOT_DIR=$(ROOT_DIR) ; \
export IS_TERRAGRUNT=$(IS_TERRAGRUNT) ; \
export ENVIRONMENT_NAME=$(ENVIRONMENT_NAME) ; \
export LAST_MAKEFILE=$(lastword $(MAKEFILE_LIST)) ; \
bash $(ROOT_DIR)/bin/terraform-docs-generate.sh

DEBUG_SERVICE = export SERVICE=$$(make working_dir | grep $$TARGET 2>/dev/null | head -1) ; \
	if [ ! -z "$$SERVICE" ] ; then \
		if [ -d "$$SERVICE" ] ; then \
			pushd $$SERVICE; \
			source $(ROOT_DIR)/cicd/rc/ansi-colors.rc ; \
			bg_terraform "You can debug terraform here e.g.: terraform plan --var-file=terragrunt-debug.tfvars.json -out=terraform.tfplan"; \
			bash -l; \
		else \
			echo "No such directory: $$SERVICE" ; \
			ls -ald $$SERVICE ; \
		fi ; \
	fi
