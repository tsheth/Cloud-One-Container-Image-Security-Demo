# Trend Micro Smart Check Demo

Spin up test environment in order to trial Trend Micro's Smart Check product.

# Instructions
1. Clone this repo:

	```
	git clone git@github.com:OzNetNerd/Deep-Security-Smart-Check-Demo.git
	```

2. Fill in the parameters for the below, then run the `cfn` template:

    Required parameters:
      * `StackName`: Name of the eksctl node CloudFormation template
	  * `AwsRegion`: Region to deploy the CloudFormation templates
	  * `VpcId`: VPC to launch the eksctl node in
	  * `SubnetId`: Subnet to launch the eksctl node in
	  * `KeyPair`: EC2 key for accessing the eksctl node
	  * `AmiId`: AWS AMI ID for Amazon Linux 2 in the specified region

    Optional parameters:
	  * `EksCtlClusterName`: Name of the EKS cluster CloudFormation template
	  * `AdminIp`: Your public IP
	 
    Command:

	```
	cd Deep-Security-Smart-Check-Demo/code
	
	aws cloudformation create-stack --stack-name <StackName> \
	--parameters ParameterKey=EksCtlClusterName,ParameterValue=<EksCtlClusterName> \
	ParameterKey=AwsRegion,ParameterValue=<AwsRegion> \
	ParameterKey=VpcId,ParameterValue=<VpcId> \
	ParameterKey=SubnetId,ParameterValue=<SubnetId> \
	ParameterKey=KeyPair,ParameterValue=<KeyPair> \
	ParameterKey=AmiId,ParameterValue=<AmiId> \
	--template-body file://cfn.yml \
	--capabilities CAPABILITY_IAM
	```
3. Obtain the hostname of the newly created EC2 instance:

    ```
    aws cloudformation describe-stacks --stack-name <StackName> --query "Stacks[0].Outputs[?OutputKey=='SmartCheckJumphost'].OutputValue" --output text
    ```
4. SSH into the jumphost and run the following command:

    ```
    ./run.sh
    ```

# Troubleshooting

If the script does not output the Smart Check details, run the following commands:

    ```
    echo ----------------------------------------------------------------------------------------------------------------
    echo Smart Check URI: "$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    echo Smart Check Username: "$(kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"
    echo Smart Check Password: "$(kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"
    echo ----------------------------------------------------------------------------------------------------------------
    ```