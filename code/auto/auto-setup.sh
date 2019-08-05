#!/usr/bin/env bash
wget https://raw.githubusercontent.com/OzNetNerd/Packer-Gitlab/master/Packer/config/docker-setup.sh
sed -e s/"sudo "//g -i docker-setup.sh
chmod +x docker-setup.sh
./docker-setup.sh
rm docker-setup.sh
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/manual/kube-setup.sh
chmod +x kube-setup.sh
./kube-setup.sh
rm kube-setup.sh
mkdir -p /home/ec2-user/.kube
eksctl create cluster --name="$1" --nodes=3 --region="$2" --kubeconfig=/home/ec2-user/.kube/config
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/manual/Makefile
mkdir /home/ec2-user/kubernetes-config
mv ./Makefile /home/ec2-user/kubernetes-config
cd /home/ec2-user/kubernetes-config
make start AWS_REGION="$2"
chown -R ec2-user:ec2-user /home/ec2-user