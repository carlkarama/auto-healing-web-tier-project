# Architecture diagram


## How to read the design

CloudFront and the associated viewer-request Function run at the global edge, outside the regional VPC. The Function chooses the primary origin randomly, approximately 50/50 across requests, and configures the other origin as the failover target. Origin groups are CloudFront configuration, not a separate network appliance. HTTPS terminates at CloudFront; requests to the public custom origins use HTTP over IPv6. Caching is disabled.

The VPC and subnets are dual-stack. Instances have private IPv4 addresses and public IPv6 addresses. A shared route table provides `::/0` through an ordinary Internet Gateway. The branching request lines represent connectivity to either origin; the branch point is not another AWS resource. Response traffic follows the corresponding return path and is omitted for readability.

Each orange dashed box represents the EC2 instance maintained by its own Auto Scaling Group. It is a logical ownership boundary, not a subnet, security boundary or additional proxy. Both groups use EC2 health checks and have minimum, desired and maximum capacity set to one. Their separate launch templates specify the AMI, NGINX bootstrap, disk and existing primary network interface. The security group described below the diagram is attached to both interfaces.

The network interface, its IPv6 address and its public IPv6 DNS hostname survive termination of the VM. The old VM must release the interface before the replacement can attach it. The root EBS volume is deleted with the terminated VM; the replacement gets a new encrypted 8 GiB gp3 root disk, including a 1 GiB swap file. CloudFront can retry the surviving origin while the other slot recovers. The connection and response timeouts shown are configuration values, not a guaranteed end-to-end failover duration. There are no periodic application health checks or ELB target groups in this design.

AZ names `us-east-1a` and `us-east-1b` match the saved plan in `terraform-plan.txt`. Terraform selects the first two available standard AZs, so another account's selection can differ. AWS assigns the VPC IPv6 `/56` and subnet `/64` ranges during provisioning; the diagram deliberately does not invent their addresses.

The monthly estimate and workload assumptions come from the README cost table. The estimate covers this proposed stack only and is not an account spending cap. It excludes any previous deployment still running in the account.