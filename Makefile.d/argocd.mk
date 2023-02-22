ROOT_DIR ?= $(PWD)/..
TERRAFORM_TEMPLATE ?= cookiecutter/cloud-services-applications
SHELL := /bin/bash
NAMESPACE ?= "argocd"
CHART_VERSION ?= '5.5.4'

.PHONY: deploy

update: # Update helm chart repos
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update

upgrade: update # Deploy helm chart
	set -x ; \
	source environment.rc ; \
	export CTX=$$(kubectl config get-contexts --output=name | grep $$AWS_DEFAULT_REGION | grep $${ACCOUNT_ID} | grep $${CLUSTER_NAME}) ; \
	helm --kube-context "$${CTX}" upgrade -i --version $(CHART_VERSION) -n $(NAMESPACE) -f ./argocd-values.yaml argocd-$$ENVIRONMENT_NAME argo/argo-cd
