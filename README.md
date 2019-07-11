# Trend Micro Smart Check Demo

Spin up test environment in order to trial Trend Micro's Smart Check product.

# Instructions

1. Clone this repo:

	```
	git clone git@github.com:OzNetNerd/Deep-Security-Smart-Check-Demo.git
	```

2. Spin up an EC2 instance:

	*Note*: `AdminIp` is optional. It defaults to `0.0.0.0/0`:

	```
	cd Deep-Security-Smart-Check-Demo/code
	aws cloudformation create-stack --stack-name eksctl-host \
	--parameters ParameterKey=AmiId,ParameterValue=<AWS_LINUX2_AMI> \
	 ParameterKey=VpcId,ParameterValue=<VPC_ID> \
	 ParameterKey=AdminIp,ParameterValue=<YOUR_PUBLIC_IP> \
	 ParameterKey=SubnetId,ParameterValue=<SUBNET_ID> \
	 ParameterKey=KeyPair,ParameterValue=<KEY_NAME> \
	 --template-body file://cfn.yml \
	 --capabilities CAPABILITY_IAM
	```
	
3. Obtain the EC2 instance hostname:

	```
	aws cloudformation \
	--region <AWS_REGION> describe-stacks \
	--stack-name=eksctl-host \
	--query 'Stacks[0].Outputs[?OutputKey==`Ec2InstanceHostname`].OutputValue' \
	--output text
	```

3. SSH into the instance and start the EKS cluster:
	
	```
	eksctl create cluster --name=<CLUSTER_NAME> \
	--nodes=3 \
	--region=<AWS_REGION>

4. Install Smart Check.

	*Note:* `<repo-name>` must be in lowercase:

	```
	make start \
	AWS_REGION=<AWS_REGION> \
	IMAGE_REPO_NAME=<repo-name>
	```

	*Note*: The Load Balancer can take a few minutes to intialise. If you cannot access the Smart Check URI after the script finishes running, continue refreshing your browser.

5. Set up Smart Check:
	1. Browse to the provided Smart Check URI.
	2. Authenticate with the provided username and password.
	3. Set a registry name and description.
	5. Set `Region`.
	6. Set `Authentication Mode` to `Instance Role`.
	7. Click **Next** to get started.

6. When you're done, stop the demo:

	```
	eksctl delete cluster \
	--name=<CLUSTER_NAME> \
	--region=<AWS_REGION>
	
	make stop \
	AWS_REGION=<AWS_REGION>
	```

**Note**: Sometimes the CloudFormation template fails to remove all resources. If this occurs, you'll need to manually delete the Load Balancer and VPC created by the demo.

## Upload Demo Images (Optional)

```
make upload-images
```