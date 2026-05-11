# Terraform Deployment

This Terraform template deploys the consumer-side Google Cloud resources required to connect a customer VPC to a Zscaler-provided Network Security Integration intercept deployment group.

## Prerequisites

- Terraform 1.5 or later
- Google provider and Google Beta provider
- Authenticated Google Cloud credentials
- Required Google Cloud APIs enabled
- IAM permissions to create Network Security, Compute firewall policy, and organization-level security profile resources
- A Zscaler-provided intercept deployment group resource ID

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
terraform init
terraform plan
terraform apply
```

For reference only, `terraform.tfvars.sample-lab` shows how the original Bash test values map into Terraform variables.

## NSI Resource Mapping

Customer projects connect to the Zscaler ZTGW service through NSI Security Profiles. The Terraform variables expose the four key resources directly:

| Resource | Terraform variable | Managed by |
| --- | --- | --- |
| Intercept Deployment Group | `intercept_deployment_group` | Zscaler producer project |
| Intercept Endpoint Group | `endpoint_group` | Customer consumer project |
| Security Profile, Custom Intercept | `security_profile` | Customer organization |
| Security Profile Group | `security_profile_group` | Customer organization |

Traffic steering follows this sequence:

```text
Firewall Rule -> Security Profile Group -> Security Profile -> Intercept Endpoint Group -> Intercept Deployment Group
```

## Build Order

The template is dependency-aware. Terraform will build resources in this order:

1. Read the existing customer VPC network.
2. Create the global firewall policy and intercept endpoint group.
3. Associate the firewall policy and endpoint group to the customer VPC.
4. Create the custom intercept security profile.
5. Create the security profile group.
6. Create ingress and egress firewall policy rules that apply the security profile group.

See `DEPENDENCIES.md` for the full dependency graph, including what is independent and what must wait.

## Notes

- This template uses `google-beta` for Network Security Integration resources.
- The providers use `billing_project_id` with `user_project_override = true`, matching the Bash template's `--billing-project` intent for organization-level Network Security calls.
- Keep the provider versions current and test against the customer's enrolled preview or beta environment.
- If the customer's provider version does not include a required NSI resource yet, use the Bash template as the operational fallback.
- Security profile and security profile group resources are organization-level resources.
- Intercept endpoint group and association resources are project-level resources.

## Cleanup

```bash
terraform destroy
```
