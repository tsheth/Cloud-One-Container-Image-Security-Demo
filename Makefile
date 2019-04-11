REGION?=ap-southeast-2
STACK_NAME?=SmartCheckDemo
REGISTRY_NAME=smart-check-demo
PASSWORD=password
ACTIVATION_CODE=
EC2_KEY_PATH=

.PHONY: validate
validate:
	@echo Validating template
	@aws cloudformation validate-template \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	> /dev/null

.PHONY: create-stack
create-stack:
	@echo Spinning up demo cluster...
	@aws cloudformation --region ${REGION} create-stack \
	--stack-name ${STACK_NAME} \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	--parameters file://vars.json \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND > \
	/dev/null

	@aws cloudformation --region ${REGION} wait stack-create-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: check-key-provided
check-key-provided:
	@if [ -z ${EC2_KEY_PATH} ]; \
	then echo Error: The EC2_KEY_PATH variable must be defined; \
	exit 1; \
	fi;

.PHONY: get-config
get-config:
# get GetKubeConfigCommand output: https://github.com/heptio/aws-quickstart/blob/master/README.md
	@make check-key-provided

	@echo Extracting IP addresses...
	@ BASTION_PUBLIC_IP="$(shell aws cloudformation --region ${REGION} describe-stacks \
	--stack-name=${STACK_NAME} \
	--query 'Stacks[0].Outputs[?OutputKey==`BastionHostPublicIp`].OutputValue' --output text)"; \
	echo Bastion IP is $$BASTION_PUBLIC_IP; \
	MASTER_PRIVATE_IP="$(shell aws cloudformation --region ${REGION} describe-stacks \
	--stack-name=${STACK_NAME} \
	--query 'Stacks[0].Outputs[?OutputKey==`MasterPrivateIp`].OutputValue' --output text)"; \
	echo Master private IP is $$MASTER_PRIVATE_IP; \
	KUBE_CFG_DIR=${HOME}/.kube/config; \
	echo Downloading Kube config file from Master node and storing it locally in $$KUBE_CFG_DIR; \
	CMD=echo scp -oStrictHostKeyChecking=no -i ${EC2_KEY_PATH} -o ProxyCommand="ssh -oStrictHostKeyChecking=no -i ${EC2_KEY_PATH} ubuntu@$$BASTION_PUBLIC_IP nc %h %p" ubuntu@$$MASTER_PRIVATE_IP:~/kubeconfig ${HOME}/.kube/config &>/dev/null;

	@sleep 10

.PHONY: setup-tiller
setup-tiller:
	@echo Setting up Tiller

	@kubectl create serviceaccount \
	--namespace kube-system \
	tiller \
	> /dev/null

	@kubectl create clusterrolebinding tiller-cluster-role \
	--clusterrole=cluster-admin \
	--serviceaccount=kube-system:tiller \
	> /dev/null

	@helm init --service-account tiller \
	> /dev/null

	@echo Sleeping for 60 seconds to allow the Tiller pod to spin up
	@sleep 60

.PHONY: install-smart-check
install-smart-check:

	@echo Installing smart-check chart
	@if [ -z ${ACTIVATION_CODE} ]; \
	then helm install \
	--name deepsecurity-smartcheck \
	--set auth.masterPassword=${PASSWORD} \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
	> /dev/null; \
	else --name deepsecurity-smartcheck \
	--set auth.masterPassword=${PASSWORD} \
	--set activationCode=${ACTIVATION_CODE} \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
	> /dev/null; \
	fi;

.PHONY: create-registry
create-registry:
	@echo Creating demo registry
	@aws --region ${REGION} ecr create-repository --repository-name ${REGISTRY_NAME} > /dev/null

.PHONY: delete-registry
delete-registry:
	@echo Deleting demo registry
	@aws --region ${REGION} ecr delete-repository --repository-name ${REGISTRY_NAME} --force > /dev/null

.PHONY: upload-images
upload-images:
	@echo Logging into demo registry
	@ECR_LOGIN="$(shell aws ecr get-login --no-include-email --region ${REGION})" &>/dev/null; \
	$$ECR_LOGIN > /dev/null; \
	echo Downloading buamod/eicar; \
	docker pull buamod/eicar > /dev/null; \
	EICAR_HASH="$(shell docker image ls | grep buamod/eicar | awk '{print $$3}')"; \
	echo Downloading vulnerables/web-dvwa ; \
	docker pull vulnerables/web-dvwa  > /dev/null; \
	DVWA_HASH="$(shell docker image ls | grep vulnerables/web-dvwa | awk '{print $$3}')"; \
	REGISTRY_URI="$(shell aws ecr describe-repositories --output text --query 'repositories[?repositoryName==`${REGISTRY_NAME}`][repositoryUri]')"; \
	echo Tagging images; \
	docker tag $$EICAR_HASH $$REGISTRY_URI:vulnerable; \
	docker tag $$DVWA_HASH $$REGISTRY_URI:infected; \
	echo Uploading buamod/eicar \(vulnerable\) to demo registry; \
	docker push $$REGISTRY_URI:vulnerable > /dev/null; \
	echo Uploading vulnerables/web-dvwa \(infected\) to demo registry; \
	docker push $$REGISTRY_URI:infected > /dev/null;

.PHONY: get-smart-check-details
get-smart-check-details:
	@echo ----------------------------------------------------------------------------------------------------------------

	@ SMARTCHECK_URL="$(shell kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"; \
	echo Smart Check URI: https://$$SMARTCHECK_URL:443/

	@ SC_USERNAME="$(shell kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Username: $$SC_USERNAME

	@ SC_PASSWORD="$(shell kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Password: $$SC_PASSWORD

	@ REGISTRY_ID="$(shell aws ecr describe-repositories --output text --query 'repositories[?repositoryName==`${REGISTRY_NAME}`][registryId]')"; \
	echo ECR Reigstry ID: $$REGISTRY_ID

	@echo ----------------------------------------------------------------------------------------------------------------

.PHONY: start-demo
start-demo: | check-key-provided validate create-registry create-stack get-config setup-tiller install-smart-check upload-images get-smart-check-details

.PHONY: update-stack
update-stack:
	@echo Updating demo cluster
	@aws cloudformation --region ${REGION} update-stack \
	--stack-name ${STACK_NAME} \
	--template-url https://aws-quickstart.s3.amazonaws.com/quickstart-vmware/templates/kubernetes-cluster-with-new-vpc.template \
	--parameters file://vars.json \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	> /dev/null

	@echo Waiting for demo cluster update to be complete
	@aws cloudformation --region ${REGION} wait stack-update-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: delete-stack
delete-stack:
	@echo Spinning down demo cluster...
	@aws cloudformation --region ${REGION} delete-stack --stack-name ${STACK_NAME} \
	> /dev/null

	@aws cloudformation --region ${REGION} wait stack-delete-complete --stack-name ${STACK_NAME} \
	> /dev/null

.PHONY: stop-demo
stop-demo: | delete-registry delete-stack