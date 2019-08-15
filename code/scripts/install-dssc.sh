#!/usr/bin/env bash
helm init
helm install --set auth.masterPassword=password --name deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz
sleep 60
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/pre-reg-scanning.sh
chmod +x pre-reg-scanning.sh
./pre-reg-scanning.sh
rm pre-reg-scanning.sh
echo ----------------------------------------------------------------------------------------------------------------
echo Smart Check URI: https://"$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo Smart Check Username: "$(kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"
echo Smart Check Password: "$(kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"
echo ----------------------------------------------------------------------------------------------------------------
