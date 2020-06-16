import boto3
import argparse
import sys
from netmiko import ConnectHandler
from time import sleep
from botocore.exceptions import ClientError
from onnmisc.aws.secrets_manager import create_secret
from onnmisc.aws.cfn import dict_to_cfn_tags, cfn_outputs_to_dict, dict_to_cfn_params
from onnmisc.transformers import convert_to_base64, base64_alphanumeric_only

DEFAULT_USERNAME = "administrator"
DEFAULT_PASSWORD = "TrendContainerImageSecurity"
POD_SLEEP_TIME = 15

CF_CLIENT = boto3.client("cloudformation")
CICD_TEMPLATE_FILE_PATH = "cfn.yml"
EKS_TEMPLATE_URL = (
    "https://s3.amazonaws.com/aws-quickstart/quickstart-amazon-eks/templates/amazon-eks-master.template.yaml"
)
PRE_REG_SCRIPT_URL = (
    "https://raw.githubusercontent.com/OzNetNerd/Deep-Security-Smart-Check-Demo/master/code/eks-pre-reg-scanning.sh"
)

# number of Container Image Security pods
NUM_CIS_PODS = 14

# Linux install commands
HELM_INSTALL_CMD = (
    f"helm install --set auth.secretSeed={DEFAULT_PASSWORD} --set auth.password={DEFAULT_PASSWORD} "
    f"deepsecurity-smartcheck https://github.com/deep-security/smartcheck-helm/archive/master.tar.gz"
)
GET_ELB_CMD = r"echo $(kubectl get svc proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
_TLS_CERT_CMD = '{{index .data "tls.crt" | base64decode}}'
GET_TLS_CERT_CMD = f"kubectl get secret dssc-proxy-certificate -o go-template='{_TLS_CERT_CMD}'"

# Linux uninstall commands
HELM_UNINSTALL_CMD = "helm uninstall deepsecurity-smartcheck"


def _get_artifact_bucket_name(cicd_stack_name):
    # generate unique name for S3 bucket
    # convert stack name to base64 with alphanumeric chars only
    cicd_stack_base64_aplhanum = base64_alphanumeric_only(cicd_stack_name)
    joined_bucket_name = f"{cicd_stack_name}-artifact-{cicd_stack_base64_aplhanum}"
    artifact_bucket_name = joined_bucket_name[:63].lower()

    return artifact_bucket_name


def _check_helm_install_status(bastion_ssh):
    while True:
        sleep(POD_SLEEP_TIME)
        total_cis_up_pods = 0

        pod_output = bastion_ssh.send_command("kubectl get pods")
        split_pod_output = pod_output.split("\n")

        for pod in split_pod_output:
            split_output = pod.split()
            pod_name = split_output[0]

            # skip header
            if pod_name == "NAME":
                continue

            status_split = split_output[1].split("/")
            up_pods = status_split[0]
            total_pods = status_split[1]

            if up_pods < total_pods:
                print(f"{pod_name}: {up_pods}/{total_pods} - Waiting for all pods to come up...")
                break

            pod_status = split_output[2]
            if pod_status != "Running":
                print(f'{pod_name}: status is "{pod_status}" - Waiting for it to change to "Running"...')
                break

            total_cis_up_pods = total_cis_up_pods + 1

        if total_cis_up_pods == NUM_CIS_PODS:
            return pod_output


def get_bastion_ssh_session(args, bastion_ip):
    key_file = args.key_file

    bastion = {
        "device_type": "linux",
        "host": bastion_ip,
        "username": "ec2-user",
        "key_file": key_file,
    }

    bastion_ssh = ConnectHandler(**bastion)

    return bastion_ssh


def get_cfn_output(stack_name, output_name):
    try:
        stack = CF_CLIENT.describe_stacks(StackName=stack_name)
        stack_outputs = stack["Stacks"][0]["Outputs"]
        outputs_dict = cfn_outputs_to_dict(stack_outputs)
        cfn_output = outputs_dict[output_name]

        return cfn_output

    except ClientError as e:
        msg = e.response["Error"]["Message"]

        if "does not exist" in msg:
            print(f'Stack "{stack_name}" does not exist')


def _get_az_names(number_of_azs):
    az_names = []

    ec2_client = boto3.client("ec2")
    all_azs = ec2_client.describe_availability_zones()

    for az_num in range(int(number_of_azs)):
        az_name = all_azs["AvailabilityZones"][az_num]["ZoneName"]
        az_names.append(az_name)

    joined_az_names = ",".join(az_names)

    return joined_az_names


def _convert_cicd_cfn_params(args, artifact_bucket_name, elb_hostname, base64_cis_cert):
    artifact_bucket_name = artifact_bucket_name

    params = {
        "CisHostname": elb_hostname,
        "CisGuiUsername": DEFAULT_USERNAME,
        "CisGuiPassword": args.password,
        "CisRegistryUsername": args.registry_username,
        "CisRegistryPassword": args.registry_password,
        "CisPublicCertificate": base64_cis_cert,
        "ArtifactBucketName": artifact_bucket_name,
    }

    cfn_params = dict_to_cfn_params(params)

    return cfn_params


def _convert_eks_cfn_params(args):
    number_of_azs = args.number_of_azs
    az_names = _get_az_names(number_of_azs)

    params = {
        "RemoteAccessCIDR": args.admin_ip,
        "KeyPairName": args.key_pair,
        "NumberOfNodes": args.number_of_nodes,
        "NumberOfAZs": number_of_azs,
        "AvailabilityZones": az_names,
    }

    cfn_params = dict_to_cfn_params(params)

    return cfn_params


def create_eks_stack(args):
    cfn_params = _convert_eks_cfn_params(args)
    stack_name = f"{args.stack_name}-EKS"

    stack_settings = {
        "StackName": stack_name,
        "TemplateURL": EKS_TEMPLATE_URL,
        "Parameters": cfn_params,
        "Capabilities": ["CAPABILITY_AUTO_EXPAND", "CAPABILITY_NAMED_IAM"],
    }

    create_stack(stack_settings)


def create_cicd_stack(args, cicd_stack_name, artifact_bucket_name, elb_hostname, base64_cis_cert):
    cicd_stack_name = cicd_stack_name
    cfn_params = _convert_cicd_cfn_params(args, artifact_bucket_name, elb_hostname, base64_cis_cert)

    with open(CICD_TEMPLATE_FILE_PATH) as f:
        template_body = f.read()

    stack_settings = {
        "StackName": cicd_stack_name,
        "TemplateBody": template_body,
        "Parameters": cfn_params,
        "Capabilities": ["CAPABILITY_IAM"],
    }

    create_stack(stack_settings)


def create_stack(stack_settings):
    stack_name = stack_settings["StackName"]

    try:
        CF_CLIENT.create_stack(**stack_settings)
        print(f'Waiting for "{stack_name}" CloudFormation template to finish building...')
        waiter = CF_CLIENT.get_waiter("stack_create_complete")
        waiter.wait(StackName=stack_name)
        print("Done")

    except ClientError as e:
        exception_name = e.response["Error"]["Code"]

        if exception_name != "AlreadyExistsException":
            sys.exit(f"Error: {e}")

        print("Cannot create stack, it already exists")


def _create_secrets(args):
    dict_tags = {"Name": "Trend Container Image Security"}
    tags = dict_to_cfn_tags(dict_tags)

    create_secret(
        "TREND_PRE_REGISTRY_PASSWORD",
        args.registry_password,
        description="Container Image Security registry password",
        tags=tags,
    )

    create_secret(
        "TREND_CIS_GUI_PASSWORD", args.password, description="Container Image Security web console password", tags=tags
    )


def start(args, eks_stack_name, cicd_stack_name, artifact_bucket_name):
    required_args = ["password", "key_pair"]

    for required_arg in required_args:
        if not getattr(args, required_arg):
            sys.exit(f'Please provide "{required_arg}" flag')

    print("Creating EKS stack. This will take approximately 30 - 45 minutes")
    create_eks_stack(args)

    bastion_ip = get_cfn_output(stack_name=eks_stack_name, output_name="BastionIP")
    print(f"Bastion IP: {bastion_ip}")

    print("Getting Bastion session...")
    bastion_ssh = get_bastion_ssh_session(args, bastion_ip)

    print("Installing Container Image Security...")
    bastion_ssh.send_command(HELM_INSTALL_CMD)

    print("Waiting for Container Image Security hostname...")
    while True:
        elb_hostname = bastion_ssh.send_command(GET_ELB_CMD)

        if elb_hostname:
            break

        sleep(POD_SLEEP_TIME)

    print(f"Found hostname: {elb_hostname}")

    print("Downloading pre-registry scanning script...")
    bastion_ssh.send_command(f"wget {PRE_REG_SCRIPT_URL}")
    bastion_ssh.send_command("chmod +x eks-pre-reg-scanning.sh")

    print("Running script...")
    reg_username = args.registry_username
    reg_password = args.registry_password
    bastion_ssh.send_command(
        f"DEFAULT_PASSWORD={DEFAULT_PASSWORD} REGISTRY_USERNAME={reg_username} REGISTRY_PASSWORD={reg_password} "
        f"./eks-pre-reg-scanning.sh"
    )

    print("Getting pod status...")
    pod_output = _check_helm_install_status(bastion_ssh)
    print(f"All Container Image Security pods are up:\n{pod_output}")

    cis_cert = bastion_ssh.send_command(GET_TLS_CERT_CMD)
    base64_cis_cert = convert_to_base64(cis_cert)

    print("Putting CI/CD pipeline secrets in Secrets Manager")
    _create_secrets(args)

    print("Creating CI/CD pipeline. This will take approximately 5 minutes")
    create_cicd_stack(args, cicd_stack_name, artifact_bucket_name, elb_hostname, base64_cis_cert)
    print("Build complete. The environment is now ready to use")

    cloud9_url = get_cfn_output(stack_name=cicd_stack_name, output_name="Cloud9Url")

    print("\n\n")
    print("Usage instructions:")
    print(f"1. Browse to the Container Image Security console: https://{elb_hostname}")
    print(f'2. Log in with the username "administrator" and password "{DEFAULT_PASSWORD}"')
    print(f'3. Change the password to "{args.password}"')
    print(f"4. (Optional): Log into the Cloud9 IDE: {cloud9_url}")
    print(f"5. (Optional): Administer k8s cluster through the Bastion host: {bastion_ip}")


def _check_helm_uninstall_status(bastion_ssh):
    while True:
        sleep(POD_SLEEP_TIME)

        pod_output = bastion_ssh.send_command("kubectl get pods")

        if "No resources found" in pod_output:
            return pod_output

        split_pod_output = pod_output.split("\n")

        for pod in split_pod_output:
            split_output = pod.split()
            pod_name = split_output[0]

            # skip header
            if pod_name == "NAME":
                continue

            pod_status = split_output[2]
            print(f'{pod_name}: status is "{pod_status}" - Waiting for it to finish deleting...')

            break


def _delete_s3_bucket_contents(bucket_name):
    s3 = boto3.resource("s3")
    bucket = s3.Bucket(bucket_name)

    try:
        bucket.objects.all().delete()

    except ClientError as e:
        msg = e.response["Error"]["Message"]

        if "does not exist" in msg:
            print(f'Bucket "{bucket_name}" does not exist')


def delete_stack(stack_name):
    CF_CLIENT.delete_stack(StackName=stack_name)
    print(f'Waiting for "{stack_name}" CloudFormation template to finish deleting...')
    waiter = CF_CLIENT.get_waiter("stack_delete_complete")
    waiter.wait(StackName=stack_name)


def arg_parse():
    parser = argparse.ArgumentParser()
    required = parser.add_argument_group("required arguments")

    required.add_argument("-a", "--action", required=True, help='"start" or "stop" the demo environment')
    required.add_argument("-s", "--stack-name", required=True, help="Base name for the CloudFormation stacks")
    required.add_argument("-f", "--key-file", required=True, help="Location of SSH key file on local system")
    parser.add_argument("-k", "--key-pair", help="SSH key pair name in AWS")
    parser.add_argument("-p", "--password", help="Container Image Security console password")
    parser.add_argument("-u", "--registry-username", default="registry", help="Pre-registry scanning username")
    parser.add_argument("-e", "--registry-password", default="password", help="Pre-registry scanning password")
    parser.add_argument("-n", "--number-of-nodes", default="2", help="Number of Kubernetes nodes")
    parser.add_argument("-z", "--number-of-azs", default="2", help="Number of Availability Zones")
    parser.add_argument("-t", "--node-instance-type", default="t3.medium", help="Node instance type")
    parser.add_argument("-i", "--admin-ip", default="0.0.0.0/0", help="Admin IP address")
    args = parser.parse_args()

    return args


def stop(args, eks_stack_name, cicd_stack_name, artifact_bucket_name):
    print("Deleting CI/CD S3 bucket contents...")
    _delete_s3_bucket_contents(artifact_bucket_name)

    print("Deleting CI/CD stack. This will take approximately 5 minutes")
    delete_stack(cicd_stack_name)
    print("Done")

    print("Preparing deletion of the EKS stack...")
    bastion_ip = get_cfn_output(stack_name=eks_stack_name, output_name="BastionIP")

    # Skip if EKS CFN doesn't exist
    if not bastion_ip:
        print("Done")

        return

    print(f"Bastion IP: {bastion_ip}")

    print("Getting Bastion session...")
    bastion_ssh = get_bastion_ssh_session(args, bastion_ip)

    print("Uninstalling Container Image Security...")
    bastion_ssh.send_command(HELM_UNINSTALL_CMD)

    print("Getting pod status...")
    pod_output = _check_helm_uninstall_status(bastion_ssh)
    print(f"All Container Image Security pods have been removed:\n{pod_output}")

    print("Deleting EKS stack. This will take approximately 15 - 30 minutes")
    delete_stack(eks_stack_name)
    print("Done")


def main():
    args = arg_parse()

    # generate stack & bucket names
    eks_stack_name = f"{args.stack_name}-EKS"
    cicd_stack_name = f"{args.stack_name}-CICD"
    args.cicd_stack_name = cicd_stack_name
    artifact_bucket_name = _get_artifact_bucket_name(cicd_stack_name)

    action = args.action.lower()

    if action == "start":
        start(args, eks_stack_name, cicd_stack_name, artifact_bucket_name)

    elif action == "stop":
        stop(args, eks_stack_name, cicd_stack_name, artifact_bucket_name)

    else:
        sys.exit('Error: Please provide a valid "action"')


if __name__ == "__main__":
    main()
