#!/usr/bin/env bash
helm install --set auth.masterPassword=password --name deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz
sleep 30
echo ----------------------------------------------------------------------------------------------------------------
echo Smart Check URI: https://"$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo Smart Check Username: "$(kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"
echo Smart Check Password: "$(kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"
echo ----------------------------------------------------------------------------------------------------------------