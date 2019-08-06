# Trend Micro Smart Check Demo

Spin up test environment in order to trial Trend Micro's Smart Check product.

# Instructions
There are two ways in which your lab can be set up - *Auto* or *Manual*.

As the name suggests, *Auto* automatically spins up an entire environment using a single command. *Manual* on the other hand, requires a couple of comamnds.

The *Auto* method is recommended for most users as it is the quickest way to get up and running. The *Manual* method is for advanced users who want to customise their EKS clusters through the `eksctl` tool.  

## Auto

1. Clone this repo:

	```
	git clone git@github.com:OzNetNerd/Deep-Security-Smart-Check-Demo.git
	```

2. Fill in the parameters for the below, then run the `auto` CFN template:

    Parameters:
	  * `EKSCTL_HOST_CFN`: Name of the eksctl node CloudFormation template 
	  * `EKSCTL_KUBE_CFN`: Name of the Kubernetes CloudFormation template
	  * `AWS_REGION`: Region to deploy the CloudFormation templates
	  * `EKSCTL_VPC_ID`: VPC to launch the eksctl node in
	  * `EKSCTL_SUBNET_ID`: Subnet to launch the eksctl node in
	  * `EC2_KEY_NAME`: EC2 key for accessing the eksctl node
	  * `AWS_LINUX2_AMI`: AWS AMI ID for Amazon Linux 2 in the specified region

    Command:

	```
	cd Deep-Security-Smart-Check-Demo/code/auto
	
	aws cloudformation create-stack --stack-name <EKSCTL_HOST_CFN> \
	--parameters ParameterKey=EksCtlClusterName,ParameterValue=<EKSCTL_KUBE_CFN> \
	ParameterKey=AwsRegion,ParameterValue=<AWS_REGION> \
	ParameterKey=VpcId,ParameterValue=<EKSCTL_VPC_ID> \
	ParameterKey=SubnetId,ParameterValue=<EKSCTL_SUBNET_ID> \
	ParameterKey=KeyPair,ParameterValue=<EC2_KEY_NAME> \
	ParameterKey=AmiId,ParameterValue=<AWS_LINUX2_AMI> \
	--template-body file://cfn.yml \
	--capabilities CAPABILITY_IAM
	```
	Two CloudFormation templates will be created sequentially. To check the status of the first, use this command:  
	
	```
	aws cloudformation wait stack-create-complete --stack-name <EKSCTL_HOST_CFN>
	```
    
    Once the first template is finished, issue the following command to check the status of the second: 

	```
	aws cloudformation wait stack-create-complete --stack-name <EKSCTL_KUBE_CFN>
	```

## Manual

1. Clone this repo:

	```
	git clone git@github.com:OzNetNerd/Deep-Security-Smart-Check-Demo.git
	```

2. Spin up an EC2 instance:

	**Note**: `AdminIp` is optional. It defaults to `0.0.0.0/0`:

	```
	cd Deep-Security-Smart-Check-Demo/code/manual
	aws cloudformation create-stack --stack-name eksctl-host \
	--parameters ParameterKey=AmiId,ParameterValue=<AWS_LINUX2_AMI> \
	 ParameterKey=VpcId,ParameterValue=<VPC_ID> \
	 ParameterKey=AdminIp,ParameterValue=<YOUR_PUBLIC_IP> \
	 ParameterKey=SubnetId,ParameterValue=<SUBNET_ID> \
	 ParameterKey=KeyPair,ParameterValue=<KEY_NAME> \
	 --template-body file://cfn.yml \
	 --capabilities CAPABILITY_IAM
	
	 aws cloudformation wait stack-create-complete --stack-name eksctl-host
	```
	
3. Obtain the EC2 instance hostname:

	```
	ssh ec2-user@<HOSTNAME> -i ~/.ssh/<KEY_NAME>
	
	aws cloudformation \
	--region <AWS_REGION> describe-stacks \
	--stack-name=eksctl-host \
	--query 'Stacks[0].Outputs[?OutputKey==`Ec2InstanceHostname`].OutputValue' \
	--output text
	```

3. SSH into the instance and start the EKS cluster.

	**Note**: You can customise the below command by following the [`eksctl` documentation](https://eksctl.io/):
	
	```
	eksctl create cluster --name=<CLUSTER_NAME> \
	--nodes=3 \
	--region=<AWS_REGION>
	```

4. Install Smart Check.

	```
	make start \
	AWS_REGION=<AWS_REGION>
	```

	**Note**: The Load Balancer can take a few minutes to intialise. If you cannot access the Smart Check URI after the script finishes running, continue refreshing your browser.

5. Set up Smart Check:
	1. Browse to the provided Smart Check URI.
	2. Authenticate with the provided username and password.
	3. Set a registry name and description.
	5. Set `Region`.
	6. Set `Authentication Mode` to `Instance Role`.
	7. Click *Next* to get started.

## Upload Demo Images (Optional)

```
make upload-images \
AWS_REGION=<AWS_REGION>
```

## Pre-registry Scanning

To enable pre-registry scanning, run the following commands:

```
wget https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/scripts/pre-reg-scanning.sh
chmod +x pre-reg-scanning.sh
./pre-reg-scanning.sh
rm pre-reg-scanning.sh
```