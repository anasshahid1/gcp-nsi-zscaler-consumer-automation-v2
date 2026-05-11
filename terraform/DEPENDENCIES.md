# Terraform Dependency Order

Terraform does not execute this template as a plain top-to-bottom script. It builds a dependency graph from resource references. This file documents that graph so customers and reviewers can understand what is created first, what can run in parallel, and what must wait.

## Independent Inputs

These must already exist or be supplied before deployment:

- Customer project ID
- Customer organization ID
- Billing project ID
- Customer VPC network
- Zscaler-provided intercept deployment group resource ID
- Traffic CIDR ranges

## Traffic Interception Chain

The intended NSI traffic mapping is:

```text
Firewall Rule -> Security Profile Group -> Security Profile -> Intercept Endpoint Group -> Intercept Deployment Group
```

In Terraform variable terms:

```text
google_compute_network_firewall_policy_rule
  -> var.security_profile_group
  -> var.security_profile
  -> var.endpoint_group
  -> var.intercept_deployment_group
```

## Step 0: Existing Data Lookup

Terraform first reads the existing customer VPC:

```hcl
data.google_compute_network.consumer
```

This does not create the VPC. It only verifies and retrieves the VPC resource ID.

## Step 1: Independent Resources

These can be created independently after inputs are known:

```hcl
google_compute_network_firewall_policy.consumer
google_network_security_intercept_endpoint_group.consumer
```

The firewall policy is required before firewall policy association and firewall rules.

The intercept endpoint group is required before endpoint group association and custom intercept security profile.

## Step 2: Resources That Depend on Step 1

These wait for Step 1 resources:

```hcl
google_compute_network_firewall_policy_association.consumer
google_network_security_intercept_endpoint_group_association.consumer
google_network_security_security_profile.custom_intercept
```

Dependency details:

- Firewall policy association waits for the firewall policy and existing VPC.
- Endpoint group association waits for the intercept endpoint group and existing VPC.
- Custom intercept security profile waits for the intercept endpoint group.

## Step 3: Security Profile Group

This waits for the custom intercept security profile:

```hcl
google_network_security_security_profile_group.consumer
```

The security profile group is what the firewall rules apply to traffic.

## Step 4: Firewall Policy Rules

These wait for both:

- Firewall policy association
- Security profile group

```hcl
google_compute_network_firewall_policy_rule.ingress_intercept
google_compute_network_firewall_policy_rule.egress_intercept
```

The ingress and egress rules are independent from each other and may be created in parallel once their shared dependencies exist.

## Dependency Diagram

```text
Existing VPC
   |\
   | \-------------------------------.
   |                                  \
Firewall Policy                       Intercept Endpoint Group
   |                                      |             |
Firewall Policy Association              |             |
   |                                      |             |
   |                          Endpoint Group Association
   |                                                    |
   |                          Custom Intercept Security Profile
   |                                                    |
   '-------------------------- Security Profile Group --'
                                |
                  .-------------'-------------.
                  |                           |
            Ingress Rule                 Egress Rule
```

## Why Explicit `depends_on` Is Used

Terraform can infer most dependencies from direct references. This template also uses explicit `depends_on` on selected preview/beta resources and final firewall rules to make the intended creation order obvious to customers and easier to troubleshoot.
