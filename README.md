# Deep Security Smart Check Demo

Spin up test environment in order to trial Trend Micro's Smart Check product.

## Technical Details 

* Creates an EC2 instance (SmartcheckJumphost) with the following security group allowing:
    * TCP 80 (HTTP)
    * TCP 22 (SSH) 
    * TCP 5000 - 5001 (Docker registry) - *see the [Smart Check CI/CD pipelines](https://github.com/OzNetNerd/Deep-Security-Smart-Check-Pipeline-GitLab) repo for more information*
* Creates an EKS cluster
* Automatically installs a self-signed certificate and enables [pre-registry scanning](https://github.com/deep-security/smartcheck-helm/wiki/Configure-pre-registry-scanning)

Note: The Smartcheck Jumphost is used to set up the environment as well interact with the Kubernetes cluster.

## Instructions
1. Clone this repo:

	```
	git clone git@github.com:OzNetNerd/Deep-Security-Smart-Check-Demo.git
	```

2. Fill in the parameters for the below, then run the `cfn` template:

    Required parameters:
      * `StackName`: Name of the Smartcheck Jumphost node CloudFormation template
	  * `VpcId`: VPC to launch the Smartcheck Jumphost node in
	  * `SubnetId`: Subnet to launch the Smartcheck Jumphost node in
	  * `KeyPair`: EC2 key for accessing the Smartcheck Jumphost node
	  * `AmiId`: AWS AMI ID for Amazon Linux 2 in the specified region

    Optional parameters:
	  * `AdminIp`: Your public IP (default 0.0.0.0/0)
	  * `JumphostInstanceSize`: Size of the Smart Check jumphost instance (default t2.micro)
	 
    Command:

	```
	cd Deep-Security-Smart-Check-Demo/code
	
	aws cloudformation create-stack --stack-name <StackName> \
	ParameterKey=VpcId,ParameterValue=<VpcId> \
	ParameterKey=SubnetId,ParameterValue=<SubnetId> \
	ParameterKey=KeyPair,ParameterValue=<KeyPair> \
	ParameterKey=AmiId,ParameterValue=<AmiId> \
	ParameterKey=AdminIp,ParameterValue=<AdminIp> \
	ParameterKey=JumphostInstanceSize,ParameterValue=<JumphostInstanceSize> \
	--template-body file://cfn.yml \
	--capabilities CAPABILITY_IAM
	```
3. Obtain the hostname of the newly created EC2 instance:

    ```
    aws cloudformation describe-stacks \
    --stack-name <StackName> \
    --query "Stacks[0].Outputs[?OutputKey=='SmartCheckJumphost'].OutputValue" \
    --output text
    ```
4. SSH into the jumphost and run the following command:

    ```
    ./run.sh <EKS_STACK_NAME> <AWS_REGION> <NUMBER_OF_NODES>
    ```
    
    e.g:

    ```
    ./run.sh smartcheck-eks ap-southeast-2 3
    ``` 

## Troubleshooting
### Docker Access

If you encounter the following error:

```
Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: 
Get http://%2Fvar%2Frun%2Fdocker.sock/v1.38/containers/json: dial unix /var/run/docker.sock: connect: permission denied
```

Terminate your SSH session and then re-log into the EC2 instance.

### Smart Check Credentials

If you forget your Smart Check URL or the default credentials, run the following commands:

```
echo Smart Check URI: "$(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo Smart Check Username: "$(kubectl get secrets -o jsonpath='{ .data.userName }' deepsecurity-smartcheck-auth | base64 --decode)"
echo Smart Check Password: "$(kubectl get secrets -o jsonpath='{ .data.password }' deepsecurity-smartcheck-auth | base64 --decode)"
```