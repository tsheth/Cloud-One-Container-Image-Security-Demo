#!/usr/bin/env bash
wget https://raw.githubusercontent.com/OzNetNerd/Packer-Gitlab/master/Packer/config/docker-setup.sh
chmod +x docker-setup.sh
./docker-setup.sh
rm docker-setup.sh
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/install-dssc.sh
chmod +x install-dssc.sh
./install-dssc.sh
rm install-dssc.sh
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/pre-reg-scanning.sh
chmod +x pre-reg-scanning.sh
./pre-reg-scanning.sh
rm pre-reg-scanning.sh
rm run.sh