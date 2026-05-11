# Bash Deployment Steps and Dependencies

Unlike Terraform, Bash does not build a dependency graph. It runs commands in the order written. For that reason, `deploy.sh` is intentionally organized into explicit steps.

## Independent Inputs

These must already exist or be supplied before running the script:

- Customer project ID
- Customer organization ID
- Billing project ID
- Customer VPC network
- Zscaler-provided intercept deployment group resource ID
- Traffic CIDR ranges

## Step 1: Create Independent Base Resources

The script creates:

```bash
gcloud compute network-firewall-policies create
gcloud beta network-security intercept-endpoint-groups create
```

These resources are independent from each other:

- The firewall policy does not depend on the endpoint group.
- The endpoint group depends on the Zscaler-provided intercept deployment group, not on the firewall policy.

They are still run sequentially in the Bash script for simpler customer logs and troubleshooting.

## Step 2: Associate Base Resources With the Consumer VPC

The script creates:

```bash
gcloud compute network-firewall-policies associations create
gcloud beta network-security intercept-endpoint-group-associations create
```

Dependency details:

- Firewall policy association depends on the firewall policy and existing VPC.
- Endpoint group association depends on the intercept endpoint group and existing VPC.

## Step 3: Create Organization-Level Security Profile Resources

The script creates:

```bash
gcloud beta network-security security-profiles custom-intercept create
gcloud beta network-security security-profile-groups create
```

Dependency details:

- Custom intercept security profile depends on the intercept endpoint group.
- Security profile group depends on the custom intercept security profile.

## Step 4: Create Firewall Policy Rules

The script creates:

```bash
gcloud compute network-firewall-policies rules create
```

Dependency details:

- Ingress rule depends on the firewall policy and security profile group.
- Egress rule depends on the firewall policy and security profile group.

The ingress and egress rules are independent from each other, but the script creates ingress first and egress second for predictable logs.

## Cleanup Order

`destroy.sh` deletes resources in reverse dependency order:

1. Firewall policy rules
2. Security profile group
3. Custom intercept security profile
4. Endpoint group association
5. Endpoint group
6. Firewall policy association
7. Firewall policy

This order avoids deleting a parent resource while child resources still reference it.
