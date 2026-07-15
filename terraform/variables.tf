# variable "impersonate_service_account" {
#   description = "Service account email to impersonate when calling GCP APIs. The caller must have roles/iam.serviceAccountTokenCreator on this SA."
#   type        = string
#   default     = "ztgw-sa@customer-project-id.iam.gserviceaccount.com"
# }

variable "deploy_key" {
  description = "Naming prefix used to create customer-side resources."
  type        = string
}

variable "project_id" {
  description = "Customer project where the consumer VPC and endpoint group are deployed."
  type        = string
}

variable "security_profile_scope" {
  description = "Parent level for security profile and security profile group resources. Use 'project' (default) for project-level deployment or 'organization' for org-level deployment (requires organization_id)."
  type        = string
  default     = "project"

  validation {
    condition     = contains(["project", "organization"], var.security_profile_scope)
    error_message = "security_profile_scope must be either 'project' or 'organization'."
  }
}

variable "organization_id" {
  description = "Customer Google Cloud organization ID. Required only when security_profile_scope is 'organization'."
  type        = string
  default     = ""

  validation {
    condition     = var.security_profile_scope != "organization" || var.organization_id != ""
    error_message = "organization_id must be provided when security_profile_scope is 'organization'."
  }
}

variable "billing_project_id" {
  description = "Billing/quota project for organization-level Network Security resources."
  type        = string
}

variable "region" {
  description = "Default provider region. NSI resources in this template use global location."
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "Location for NSI resources. Current NSI consumer resources commonly use global."
  type        = string
  default     = "global"
}

variable "consumer_network" {
  description = "Customer VPC network name."
  type        = string
}

variable "intercept_deployment_group" {
  description = "Zscaler-provided intercept deployment group resource ID."
  type        = string
}

variable "consumer_fw_policy" {
  description = "Optional override for the global network firewall policy name."
  type        = string
  default     = ""
}

variable "consumer_fw_policy_association" {
  description = "Optional override for the firewall policy association name."
  type        = string
  default     = ""
}

variable "security_profile" {
  description = "Optional override for the custom intercept security profile name."
  type        = string
  default     = ""
}

variable "security_profile_group" {
  description = "Optional override for the security profile group name."
  type        = string
  default     = ""
}

variable "endpoint_group" {
  description = "Optional override for the intercept endpoint group name."
  type        = string
  default     = ""
}

variable "endpoint_group_association" {
  description = "Optional override for the intercept endpoint group association name."
  type        = string
  default     = ""
}

variable "ingress_rule_priority" {
  description = "Priority for the ingress firewall policy rule."
  type        = number
  default     = 100
}

variable "allow_ingress_rule_priority" {
  description = "Priority for the allow-list ingress firewall policy rule (evaluated before the intercept rule)."
  type        = number
  default     = 90
}

variable "allow_ingress_source_ranges" {
  description = "Source CIDR ranges that should be allowed without Zscaler inspection."
  type        = list(string)
  default     = ["34.117.59.81/32"]
}

variable "egress_rule_priority" {
  description = "Priority for the egress firewall policy rule."
  type        = number
  default     = 101
}

variable "ingress_source_ranges" {
  description = "Source CIDR ranges for inbound traffic inspection."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "egress_destination_ranges" {
  description = "Destination CIDR ranges for outbound traffic inspection."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_firewall_logging" {
  description = "Enable logging on the created firewall policy rules."
  type        = bool
  default     = true
}
