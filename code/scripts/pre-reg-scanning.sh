#!/bin/bash
SMARTCHECK_URL=$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

cd /tmp

echo 'Generating self-signed certificate for ' $SMARTCHECK_URL

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
-keyout dssc.key -out dssc.crt -subj '/CN=example.com' \
-extensions san \
-config <(echo '[req]'; echo 'distinguished_name=req';
echo '[san]'; echo 'subjectAltName=DNS:'$SMARTCHECK_URL) \
&>/dev/null

echo 'Creating Kubernetes secret: dssc-proxy-certificate'

kubectl create secret tls dssc-proxy-certificate \
--namespace default \
--cert=dssc.crt \
--key=dssc.key \
&>/dev/null

wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/auto/overrides.yaml &>/dev/null

echo 'Enabling pre-registry scanning'

helm upgrade \
--values overrides.yaml \
deepsecurity-smartcheck \
https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz --reuse-values \
&>/dev/null

echo 'Deleting proxy pod'

kubectl delete pods \
--namespace default \
-l "service=proxy,release=deepsecurity-smartcheck" \
&>/dev/null

echo Copying Smart Check certificate to /etc/docker/certs.d/$SMARTCHECK_URL\:5000/ca.crt

kubectl get secret dssc-proxy-certificate -o go-template='{{index .data "tls.crt" | base64decode}}' >  ca.crt
sudo mkdir -p /etc/docker/certs.d/$SMARTCHECK_URL\:5000/
sudo mv ca.crt /etc/docker/certs.d/$SMARTCHECK_URL\:5000/ca.crt
