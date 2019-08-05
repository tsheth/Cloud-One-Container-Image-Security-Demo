AWS_REGION=
IMAGE_REPO_NAME=
PASSWORD=password
ACTIVATION_CODE=

.PHONY: start
start: | setup-tiller install-smart-check get-smart-check-details

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
	else helm install \
	--name deepsecurity-smartcheck \
	--set auth.masterPassword=${PASSWORD} \
	--set activationCode=${ACTIVATION_CODE} \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz \
	> /dev/null; \
	fi;

.PHONY: create-image-repo
create-image-repo:
	@echo Creating demo image repository
	@aws ecr create-repository --region ${AWS_REGION} --repository-name ${IMAGE_REPO_NAME} > /dev/null

.PHONY: delete-image-repo
delete-image-repo:
	@echo Deleting demo image repository
	@aws --region ${AWS_REGION} ecr delete-repository --repository-name ${IMAGE_REPO_NAME} --force > /dev/null

.PHONY: upload-images
upload-images | create-image-repo:
	@echo Logging into demo image registry
	@ECR_LOGIN="$(shell aws ecr get-login --no-include-email --region ${AWS_REGION})"; \
	eval $$ECR_LOGIN > /dev/null; \
	echo Downloading buamod/eicar; \
	docker pull buamod/eicar > /dev/null; \
	EICAR_HASH="$(shell docker image ls | grep buamod/eicar | awk '{print $$3}')"; \
	echo Downloading vulnerables/web-dvwa ; \
	docker pull vulnerables/web-dvwa  > /dev/null; \
	DVWA_HASH="$(shell docker image ls | grep vulnerables/web-dvwa | awk '{print $$3}')"; \
	IMAGE_REPO_URI="$(shell aws ecr describe-repositories --output text --query 'repositories[?repositoryName==`${IMAGE_REPO_NAME}`][repositoryUri]')"; \
	sleep 5; \
	echo Tagging images; \
	docker tag $$EICAR_HASH $$IMAGE_REPO_URI:vulnerable; \
	docker tag $$DVWA_HASH $$IMAGE_REPO_URI:infected; \
	echo Uploading buamod/eicar \(vulnerable\) to demo repository; \
	docker push $$IMAGE_REPO_URI:vulnerable > /dev/null; \
	echo Uploading vulnerables/web-dvwa \(infected\) to demo repository; \
	docker push $$IMAGE_REPO_URI:infected > /dev/null;

.PHONY: get-smart-check-details
get-smart-check-details:
	@sleep 5; \
	echo ----------------------------------------------------------------------------------------------------------------; \
	SMARTCHECK_URL="$(shell kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"; \
	echo Smart Check URI: https://$$SMARTCHECK_URL:443/;\
	SC_USERNAME="$(shell kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Username: $$SC_USERNAME; \
	SC_PASSWORD="$(shell kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"; \
	echo Smart Check Password: $$SC_PASSWORD; \
	echo ----------------------------------------------------------------------------------------------------------------;


.PHONY: enable-pre-reg
enable-pre-reg:
	SMARTCHECK_URL="$(shell kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"; \
	cd /tmp; \
	openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
	-keyout dssc.key -out dssc.crt -subj '/CN=example.com' \
	-extensions san \
	-config <(echo '[req]'; echo 'distinguished_name=req'; \
	echo '[san]'; echo 'subjectAltName=DNS:$$SMARTCHECK_URL'); \
	kubectl create secret tls dssc-proxy-certificate \
    --namespace default \
    --cert=dssc.crt \
    --key=dssc.key; \
	wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/auto/overrides.yaml; \
	helm upgrade \
	--values overrides.yaml \
	deepsecurity-smartcheck \
	https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz --reuse-values;
	kubectl delete pods \
	--namespace default \
	-l "service=proxy,release=deepsecurity-smartcheck"; \
	kubectl get secret dssc-proxy-certificate -o go-template='{{index .data "tls.crt" | base64decode}}'; \
	sudo mkdir -p /etc/docker/certs.d/$$SMARTCHECK_URL:5000/;


