#!/usr/bin/env bash
wget https://raw.githubusercontent.com/OzNetNerd/Packer-Gitlab/master/Packer/config/docker-setup.sh
chmod +x docker-setup.sh
./docker-setup.sh
rm docker-setup.sh
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/kube-setup.sh
chmod +x kube-setup.sh
# k8s CFN name & region
./kube-setup.sh "$1" "$2"
rm kube-setup.sh
rm auto.sh
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/pre-reg-scanning.sh
chmod +x pre-reg-scanning.sh
./pre-reg-scanning.sh
rm pre-reg-scanning.sh