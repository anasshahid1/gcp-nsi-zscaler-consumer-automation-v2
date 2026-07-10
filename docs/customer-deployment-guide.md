# Customer Deployment Guide

## Purpose

This guide explains how a customer can deploy the consumer-side Google Cloud resources needed to connect a VPC network to a Zscaler-provided Google Cloud Network Security Integration intercept deployment group.

The automation is intended for customer-side deployment. It does not create the Zscaler producer-side cloud connector, intercept deployment, or intercept deployment group.

## Deployment Flow

The customer-side deployment creates:

1. A global network firewall policy in the customer project.
2. A firewall policy association between that policy and the customer VPC.
3. An intercept endpoint group that references the Zscaler-provided intercept deployment group.
4. An intercept endpoint group association that connects the endpoint group to the customer VPC.
5. A custom intercept security profile at the customer organization level.
6. A security profile group at the customer organization level.
7. Firewall policy rules that apply the security profile group to selected ingress and egress traffic.

## Responsibility Split

### Zscaler Provides

- Intercept deployment group resource ID.
- Required service availability or beta enrollment guidance.
- Required IAM role guidance.
- Recommended traffic selection criteria.
- Any tenant-specific deployment naming or policy guidance.

### Customer Provides

- GCP project ID.
- GCP organization ID.
- Billing project ID.
- VPC network name.
- Ingress source CIDR ranges.
- Egress destination CIDR ranges.
- Deployment prefix.
- Authenticated identity with required permissions.

## Resource Scope

| Resource | Scope | Owner |
| --- | --- | --- |
| Network firewall policy | Customer project, global | Customer |
| Firewall policy association | Customer project, VPC | Customer |
| Intercept endpoint group | Customer project, global | Customer |
| Intercept endpoint group association | Customer project, VPC | Customer |
| Custom intercept security profile | Customer organization, global | Customer |
| Security profile group | Customer organization, global | Customer |
| Intercept deployment group | Zscaler/producer project | Zscaler |

## Required APIs

Customers should confirm the following APIs are enabled where applicable:

```bash
gcloud services enable compute.googleapis.com --project CUSTOMER_PROJECT_ID
gcloud services enable networksecurity.googleapis.com --project CUSTOMER_PROJECT_ID
```

Depending on the customer environment, organization-level Network Security operations may require the billing project to have `networksecurity.googleapis.com` enabled.

## IAM Requirements

The deploying identity needs permissions to:

- Create and manage Compute network firewall policies.
- Associate a global firewall policy to the target VPC.
- Create Network Security intercept endpoint groups.
- Create Network Security intercept endpoint group associations.
- Create organization-level custom intercept security profiles.
- Create organization-level security profile groups.

At minimum, customers should validate access with their Google Cloud administrator. Exact role names can vary while preview or beta capabilities are being enabled. Zscaler should provide the currently required IAM role guidance as part of onboarding.

## Bash Deployment

The Bash deployment runs commands sequentially. It is organized into explicit steps so the customer can see which resources are independent and which resources depend on earlier resources:

1. Create independent base resources: firewall policy and intercept endpoint group.
2. Associate base resources with the consumer VPC.
3. Create organization-level security profile resources.
4. Create firewall policy rules that apply the security profile group.

See `bash/STEPS.md` for the full Bash order and cleanup dependency details.

### 1. Prepare Config

```bash
cd bash
cp config.example.env config.env
vi config.env
```

Update these required values:

```bash
DEPLOY_KEY="customer-nsi"
PROJECT_ID="customer-project-id"
ORGANIZATION_ID="123456789012"
BILLING_PROJECT_ID="customer-project-id"
CONSUMER_NETWORK="customer-vpc-network"
LOCATION="global"
INTERCEPT_DEPLOYMENT_GROUP="projects/zscaler-producer-project/locations/global/interceptDeploymentGroups/customer-deployment-group"
INGRESS_SOURCE_RANGES="10.1.0.0/16"
EGRESS_DESTINATION_RANGES="0.0.0.0/0"
```

### 2. Optional Dry Run

```bash
DRY_RUN="true"
./deploy.sh config.env
```

Or set `DRY_RUN="true"` inside `config.env`.

### 3. Deploy

```bash
./deploy.sh config.env
```

The script prints a deployment summary before creating resources.

### 4. Validate

Replace values as needed if custom names were used.

```bash
gcloud beta network-security intercept-endpoint-groups describe CUSTOMER_NSI-intercept-endpoint-group \
  --location=global \
  --project=CUSTOMER_PROJECT_ID

gcloud beta network-security intercept-endpoint-group-associations describe CUSTOMER_NSI-intercept-endpoint-group-association \
  --location=global \
  --project=CUSTOMER_PROJECT_ID

gcloud beta network-security security-profile-groups describe CUSTOMER_NSI-security-profile-group \
  --location=global \
  --organization=CUSTOMER_ORG_ID \
  --billing-project=CUSTOMER_PROJECT_ID

gcloud compute network-firewall-policies rules list \
  --firewall-policy=CUSTOMER_NSI-consumer-policy \
  --global-firewall-policy \
  --project=CUSTOMER_PROJECT_ID
```

### 5. Cleanup

```bash
./destroy.sh config.env
```

Cleanup removes the policy rules first, then security profile resources, endpoint resources, the firewall policy association, and finally the firewall policy.

## Terraform Deployment

Terraform creates resources from a dependency graph. The template includes explicit dependencies for the most important NSI sequence:

1. Read existing customer VPC.
2. Create independent base resources: firewall policy and intercept endpoint group.
3. Create VPC associations.
4. Create custom intercept security profile.
5. Create security profile group.
6. Create ingress and egress policy rules.

See `terraform/DEPENDENCIES.md` for the full graph.

### 1. Prepare Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

Update:

```hcl
deploy_key         = "customer-nsi"
project_id         = "customer-project-id"
organization_id    = "123456789012"
billing_project_id = "customer-project-id"
consumer_network   = "customer-vpc-network"

intercept_deployment_group = "projects/zscaler-producer-project/locations/global/interceptDeploymentGroups/customer-deployment-group"
```

### 2. Initialize

```bash
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

### 5. Cleanup

```bash
terraform destroy
```

## Traffic Selection

The sample deploys:

- Ingress inspection for `10.1.0.0/16`.
- Egress inspection for `0.0.0.0/0`.

Customers should adjust this based on their traffic steering design. Avoid overly broad inspection during initial testing unless the customer explicitly wants full-path validation.

## NSI Resource Mapping

Customer projects, also called consumer projects, connect to the Zscaler ZTGW service through NSI Security Profiles.

The key resources are:

| Resource | Description | Where it is managed |
| --- | --- | --- |
| Intercept Deployment Group | Zscaler-managed resource representing ZTGW infrastructure. Copy this value from the Zscaler portal. | Zscaler producer project |
| Intercept Endpoint Group | Customer-created global resource that binds to the Zscaler-provided Intercept Deployment Group. | Customer consumer project |
| Security Profile, Custom Intercept | Organization-level resource that defines inspection behavior and links to the customer's Intercept Endpoint Group. | Customer organization |
| Security Profile Group | Container that aggregates Security Profiles and is referenced by Global Network Firewall Policy rules. | Customer organization |

Traffic steering follows this mapping:

```text
Firewall Rule -> Security Profile Group -> Security Profile -> Intercept Endpoint Group -> Intercept Deployment Group (Zscaler ZTGW)
```

## Naming

By default, names can be generated from `DEPLOY_KEY` or `deploy_key`, but the customer Terraform example lists the core NSI resource names explicitly so reviewers can see each object before deployment.

Example:

```text
customer-nsi-consumer-policy
customer-nsi-consumer-policy-association
customer-nsi-intercept-endpoint-group
customer-nsi-intercept-endpoint-group-association
customer-nsi-custom-intercept-profile
customer-nsi-security-profile-group
```

Each name can be overridden in the Bash config or Terraform variables.

## Troubleshooting

### Permission denied when creating security profiles

Security profiles and security profile groups are organization-level resources. Confirm the deploying identity has the required organization-level permissions.

### Endpoint group cannot reference intercept deployment group

Confirm the Zscaler-provided intercept deployment group ID is correct and that the customer has been granted access to consume it.

### Firewall rule creation fails

Confirm the security profile group exists, the resource ID is correct, and the global firewall policy is associated with the intended VPC.

### Terraform provider does not recognize an NSI resource

Update the Google and Google Beta providers. If the customer environment still does not support the resource through Terraform, use the Bash deployment path until provider support is available.

## Production Readiness Checklist

- Confirm feature availability for the customer project and organization.
- Confirm APIs are enabled.
- Confirm IAM permissions with least privilege.
- Confirm Zscaler-provided intercept deployment group ID.
- Confirm traffic CIDR ranges.
- Confirm firewall policy priority values do not conflict.
- Run Bash dry-run or Terraform plan.
- Validate created endpoint group and association.
- Validate security profile group.
- Validate firewall policy rules.
- Document cleanup process before pilot testing.
