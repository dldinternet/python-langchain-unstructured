ROOT_DIR ?= $(PWD)/..
TERRAFORM_TEMPLATE ?= cookiecutter/cloud-services-applications
TERRAGRUNT_TEMPLATE ?= cookiecutter/cloud-services-terragrunt
IS_MONOREPO ?= no
SHELL := /bin/bash
include $(ROOT_DIR)/Makefile.d/help.mk
.DEFAULT_GOAL := use_cases
include $(ROOT_DIR)/Makefile.d/aws.mk
include $(ROOT_DIR)/Makefile.d/python.mk
include $(ROOT_DIR)/Makefile.d/terraform.mk
#include $(ROOT_DIR)/Makefile.d/lint.mk
include $(ROOT_DIR)/Makefile.d/k8s.mk

CLUSTER_NAMES := if [ ! -z "$$CLUSTER_NAME" ]; then CLUSTER_NAMES="$$CLUSTER_NAME"; else CLUSTER_NAMES=$$(aws eks --region $${AWS_DEFAULT_REGION:-us-east-2} list-clusters --output=text --profile=$(AWS_PROFILE) --query='@.clusters' | grep $(ENVIRONMENT_NAME)); fi
UPDATE_KUBECONFIG := [ -z "$$CLUSTER_NAME" ] || aws eks --region $${AWS_DEFAULT_REGION:-us-east-2} update-kubeconfig --name $$CLUSTER_NAME --profile=$(AWS_PROFILE)
UPDATE_KUBECONFIG_ALL := [ -z "$$CLUSTER_NAMES" ] || for CLUSTER_NAME in $$CLUSTER_NAMES; do echo $$CLUSTER_NAME ; aws eks --region $${AWS_DEFAULT_REGION:-us-east-2} update-kubeconfig --name $$CLUSTER_NAME --profile=$(AWS_PROFILE) ; done
ARGOCD_LOGIN := [ -z "$${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)}" ] || argocd login $${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)} --sso --username $${ARGOCD_USERNAME:-$(ARGOCD_USERNAME)}

.PHONY: help templates use_cases changelog
use_cases: help # Show this use cases
	@echo "Typical use case:"
	@echo "  make aws_sso - Prepare credentials"
	@echo "  make init    - Install terraform modules"
	@echo "  make plan    - Plan the infrastructure changes and insect"
	@echo "  make apply   - Apply the infrastructure changes (Repeat plan/apply if necessary)"

doctor: # Check the environment
	$(SHELL) $(ROOT_DIR)/bin/doctor.sh
