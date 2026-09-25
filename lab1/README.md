# Lab 1 Scripts

This folder contains four AWS CLI wrapper scripts used to provision and tear down
a temporary EC2 test environment for Lab 1.

## create-security-group.sh
Creates a security group named `acs730-week1-sg` and adds an inbound rule that
allows SSH (port 22) only from the current machine's public IP address, detected
automatically via checkip.amazonaws.com. This follows the principle of least
privilege by avoiding open access from the entire internet.

## create-instance.sh
Looks up the latest Amazon Linux 2023 AMI using AWS Systems Manager, then
launches a single t3.micro EC2 instance tagged with the name `acs730-week1`.
The instance is launched with the `LabInstanceProfile` IAM role attached so it
can authenticate to AWS without needing stored credentials.

## delete-instance.sh
Finds any running, pending, or stopped instance tagged `acs730-week1` and
terminates it. If no matching instance is found, it prints a message instead
of failing, which makes it safe to run more than once.

## delete-security-group.sh
Deletes the `acs730-week1-sg` security group by name. This is meant to be run
after the test instance has fully terminated, since AWS won't allow deleting a
security group that's still attached to a running resource.

## Usage
Run the two create scripts to spin up the test environment, verify the
resources in the AWS Console, then run the two delete scripts to tear
everything down and avoid unnecessary charges.
# Lab 1

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 1 in this folder.
