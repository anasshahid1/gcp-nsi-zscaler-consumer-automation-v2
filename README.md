# Zscaler GCP NSI Consumer Automation

This package provides customer-side automation templates for deploying Google Cloud Network Security Integration resources that connect a consumer VPC to a Zscaler-provided intercept deployment group.

The package includes:

- A Bash deployment template using `gcloud`
- A Bash cleanup template
- A Terraform template using the Google and Google Beta providers
- Customer-facing deployment documentation

> Important: Google Cloud Network Security Integration capabilities may be beta or preview depending on the customer's environment and provider version. Validate the exact API availability, IAM roles, and Zscaler-provided intercept deployment group details before using this in production.

## Package Structure

```text
gcp-nsi-zscaler-consumer-automation/
├── .gitignore
├── README.md
├── bash/
│   ├── config.example.env
│   ├── deploy.sh
│   ├── destroy.sh
│   └── STEPS.md
├── terraform/
│   ├── README.md
│   ├── DEPENDENCIES.md
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── terraform.tfvars.sample-lab
│   ├── variables.tf
│   └── versions.tf
└── docs/
    └── customer-deployment-guide.md
```

## What This Deploys

The templates create the following consumer-side resources:

- Global network firewall policy
- Firewall policy association to the consumer VPC
- Intercept endpoint group
- Intercept endpoint group association to the consumer VPC
- Custom intercept security profile
- Security profile group
- Ingress firewall policy rule applying the security profile group
- Egress firewall policy rule applying the security profile group

## Values Provided by Zscaler

Zscaler or the service provider should provide:

- Intercept deployment group resource ID
- Any required deployment group location or region guidance
- Required IAM role guidance
- Recommended traffic match criteria

## Values Provided by the Customer

The customer provides:

- GCP project ID
- GCP organization ID
- Consumer VPC network name
- Deployment prefix
- Ingress source CIDR ranges
- Egress destination CIDR ranges
- Billing project, if different from the deployment project

## Quick Start: Bash

```bash
cd bash
cp config.example.env config.env
vi config.env
./deploy.sh config.env
```

To clean up:

```bash
./destroy.sh config.env
```

Bash command order and cleanup dependencies are documented in `bash/STEPS.md`.

## Quick Start: Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
terraform init
terraform plan
terraform apply
```

Terraform dependency details are documented in `terraform/DEPENDENCIES.md`.

## Documentation

See `docs/customer-deployment-guide.md` for the detailed deployment guide, prerequisites, IAM notes, validation commands, cleanup, and troubleshooting.
