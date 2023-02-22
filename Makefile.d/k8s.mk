ROOT_DIR ?= $(PWD)/..

kubeconfig: # Update kubeconfig for the cluster
	test ! -f environment.rc || . environment.rc ; \
	echo AWS_DEFAULT_REGION=$$AWS_DEFAULT_REGION ; \
	echo AWS_REGION=$$AWS_REGION ; \
	$(CLUSTER_NAMES) ; \
	echo CLUSTER_NAMES=$$CLUSTER_NAMES ; \
	for CLUSTER_NAME in $$CLUSTER_NAMES; do \
		$(UPDATE_KUBECONFIG) ; \
	done

	#set -x ; \
	#set | grep '^AWS_' ; \


register: kubeconfig # Add the cluster to the ArgoCD instance
	@[ ! -z "$${ARGOCD_HOSTNAME:-$(ARGOCD_HOSTNAME)}" ] || { echo 'Set ARGOCD_HOSTNAME' ; exit 1 ; }
	@[ ! -z "$${ARGOCD_USERNAME:-$(ARGOCD_USERNAME)}" ] || { echo 'Set ARGOCD_USERNAME' ; exit 1 ; }
	set -o errexit ; $(ARGOCD_LOGIN) ; \
	ARGOCD_CLUSTERS=$$( argocd cluster list 2>&1 | grep $(ENVIRONMENT_NAME) 2>/dev/null || true) ; \
	echo ARGOCD_CLUSTERS=$$ARGOCD_CLUSTERS ; \
	if [ -z "$$ARGOCD_CLUSTERS" ] ; then \
		$(CLUSTER_NAMES) ; \
		[ -z "$$CLUSTER_NAMES" ] || for CLUSTER_NAME in $$CLUSTER_NAMES; do \
			[ -z "$$(echo $$CLUSTER_NAME | grep $(ENVIRONMENT_NAME))" ] || { echo CLUSTER_NAME=$$CLUSTER_NAME ; \
				KUBECTL_CONTEXT=$$(kubectl config get-contexts | grep $$CLUSTER_NAME | grep $(ENVIRONMENT_NAME) | awk '{ print $$2}') ; \
				echo KUBECTL_CONTEXT=$$KUBECTL_CONTEXT ; \
				[ ! -z "$$KUBECTL_CONTEXT" ] && { \
					KUBECTL_CLUSTER=$$(echo $$KUBECTL_CONTEXT | cut -d / -f 2) ; \
					echo KUBECTL_CLUSTER=$$KUBECTL_CLUSTER ; \
					argocd cluster add $$KUBECTL_CONTEXT --name=$$KUBECTL_CLUSTER -y ; \
				} ; \
			} ; \
		done ; \
		else echo "$(ENVIRONMENT_NAME) already registered" ; \
		fi ; \
