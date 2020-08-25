SMARTCHECK_URL=$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
cd /tmp
echo 'Generating self-signed certificate for' $SMARTCHECK_URL
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
-keyout dssc.key -out dssc.crt -subj '/CN=example.com' \
-extensions san \
-config <(echo '[req]'; echo 'distinguished_name=req';
echo '[san]'; echo 'subjectAltName=DNS:'$SMARTCHECK_URL)
echo 'Creating Kubernetes secret: dssc-proxy-certificate'
kubectl create secret tls dssc-proxy-certificate \
--namespace default \
--cert=dssc.crt \
--key=dssc.key
echo 'Enabling pre-registry scanning'
helm upgrade \
--set auth.secretSeed=$DEFAULT_PASSWORD \
--set auth.password=$DEFAULT_PASSWORD \
--set registry.enabled=true \
--set registry.auth.username=$REGISTRY_USERNAME \
--set registry.auth.password=$REGISTRY_PASSWORD \
--set certificate.secret.name=dssc-proxy-certificate \
--set certificate.secret.certificate=tls.crt \
--set certificate.secret.privateKey=tls.key \
deepsecurity-smartcheck \
https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz
echo 'Deleting proxy pod'
kubectl delete pods \
--namespace default \
-l "service=proxy,release=deepsecurity-smartcheck"
