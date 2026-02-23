

## Diagram
![Diagram](.resources/tgw-multi-region.png)


## Considerations
- Traffic between the Prod and Dev environments will be isolated by using different Transit Gateway Routing Tables.
- All the resources in this deployment belong to a single AWS account.
- This repo is not intended to be used in a production environment but to help testing and understanding how to build a global network infrastructure with AWS.
- By default, an AWS account is limited to 5 Elastic IPs per region. For this reasons, we only have configured one NGW in each VPC in each region. The NGW will be configured in the public-subnet-1 on each VPC/Cell. In production, you can use one NGW per each public subnets for maximum redundancy.
- This repo has been deployed with an IAM user and a policy that provides admin access. In a production environment, you'd want to grant the least privilege for users to deploy their resources.


## Regions


## IP Allocation

The allocation follows a hierarchical structure:
- Each region gets a /12 block
- Within each region, Prod gets one /16 and Dev gets another /16
- Each VPC (cell) gets a /20 from its environment's /16 block
- This provides room for 16 VPCs per environment per region (16 × /20 = /16)

| VPC Name | Environment | VPC CIDR | Region/Env Summary | Region |
|----------|-------------|----------|-------------------|---------|
| vpc-euw2-prod-cell0000 | Prod | 10.0.0.0/20 | 10.0.0.0/16 | eu-west-2 - London |
| vpc-euw2-prod-cell0001 | Prod | 10.0.16.0/20 | | |
| vpc-euw2-dev-cell1000 | Dev | 10.1.0.0/20 | 10.1.0.0/16 | |
| vpc-euw2-dev-cell1001 | Dev | 10.1.16.0/20 | | |
| vpc-euw1-prod-cell2000 | Prod | 10.16.0.0/20 | 10.16.0.0/16 | eu-west-1 - Ireland |
| vpc-euw1-prod-cell2001 | Prod | 10.16.16.0/20 | | |
| vpc-euw1-dev-cell3000 | Dev | 10.17.0.0/20 | 10.17.0.0/16 | |
| vpc-euw1-dev-cell3001 | Dev | 10.17.16.0/20 | | |
| vpc-usw2-prod-cell4000 | Prod | 10.32.0.0/20 | 10.32.0.0/16 | us-west-2 - Oregon |
| vpc-usw2-prod-cell4001 | Prod | 10.32.16.0/20 | | |
| vpc-usw2-dev-cell5000 | Dev | 10.33.0.0/20 | 10.33.0.0/16 | |
| vpc-usw2-dev-cell5001 | Dev | 10.33.16.0/20 | | |
| vpc-usw1-prod-cell6000 | Prod | 10.48.0.0/20 | 10.48.0.0/16 | us-west-1 - N California |
| vpc-usw1-prod-cell6001 | Prod | 10.48.16.0/20 | | |
| vpc-usw1-dev-cell7000 | Dev | 10.49.0.0/20 | 10.49.0.0/16 | |
| vpc-usw1-dev-cell7001 | Dev | 10.49.16.0/20 | | |

## Transit Gateway

### ASNs

euw2: 64514
euw1: 64515
usw1: 64516
usw2: 64517


### TGW Route Tables
- 3 Different Route Tables (prod, dev and shared)
    - Prod cant' communicate with Dev and the other way around.
    - Shared can communicate with both Prod and Dev.
    - VPCs tagged with environment = dev will be attached to the dev routing table
    - VPCs tagged with environment = prod will be attached to the prod routing table
    - All VPCs will also be attached to the shared routing table.



## State files
- One State file for VPCs and EC2
- Another State file for 