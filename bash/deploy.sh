#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./deploy.sh <config.env>

Deploys customer-side Google Cloud Network Security Integration resources for
Zscaler intercept integration.

Example:
  cp config.example.env config.env
  vi config.env
  ./deploy.sh config.env
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "==> $*"
}

step() {
  echo
  echo "==> Step $1: $2"
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    "$@"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_var() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "Missing required variable: $name"
}

default_if_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "${!name:-}" ]]; then
    printf -v "$name" '%s' "$value"
  fi
}

[[ $# -eq 1 ]] || {
  usage
  exit 1
}

CONFIG_FILE="$1"
[[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"

# shellcheck disable=SC1090
source "$CONFIG_FILE"

require_command gcloud

require_var DEPLOY_KEY
require_var PROJECT_ID
require_var ORGANIZATION_ID
require_var BILLING_PROJECT_ID
require_var CONSUMER_NETWORK
require_var LOCATION
require_var INTERCEPT_DEPLOYMENT_GROUP
require_var INGRESS_RULE_PRIORITY
require_var EGRESS_RULE_PRIORITY
require_var INGRESS_SOURCE_RANGES
require_var EGRESS_DESTINATION_RANGES

default_if_empty CONSUMER_FW_POLICY "${DEPLOY_KEY}-consumer-policy"
default_if_empty CONSUMER_FW_POLICY_ASSOC "${DEPLOY_KEY}-consumer-policy-association"
default_if_empty SECURITY_PROFILE "${DEPLOY_KEY}-custom-intercept-profile"
default_if_empty SECURITY_PROFILE_GROUP "${DEPLOY_KEY}-security-profile-group"
default_if_empty ENDPOINT_GROUP "${DEPLOY_KEY}-intercept-endpoint-group"
default_if_empty ENDPOINT_GROUP_ASSOCIATION "${DEPLOY_KEY}-intercept-endpoint-group-association"

SECURITY_PROFILE_GROUP_RESOURCE="organizations/${ORGANIZATION_ID}/locations/${LOCATION}/securityProfileGroups/${SECURITY_PROFILE_GROUP}"
ENDPOINT_GROUP_RESOURCE="projects/${PROJECT_ID}/locations/${LOCATION}/interceptEndpointGroups/${ENDPOINT_GROUP}"

LOGGING_FLAG=()
if [[ "${ENABLE_FIREWALL_LOGGING:-false}" == "true" ]]; then
  LOGGING_FLAG=(--enable-logging)
fi

log "Deployment summary"
cat <<SUMMARY
Project:                         ${PROJECT_ID}
Organization:                    ${ORGANIZATION_ID}
Billing project:                 ${BILLING_PROJECT_ID}
Consumer network:                ${CONSUMER_NETWORK}
Location:                        ${LOCATION}
Intercept deployment group:      ${INTERCEPT_DEPLOYMENT_GROUP}
Firewall policy:                 ${CONSUMER_FW_POLICY}
Security profile:                ${SECURITY_PROFILE}
Security profile group:          ${SECURITY_PROFILE_GROUP}
Intercept endpoint group:        ${ENDPOINT_GROUP}
Endpoint group association:      ${ENDPOINT_GROUP_ASSOCIATION}
Ingress source ranges:           ${INGRESS_SOURCE_RANGES}
Egress destination ranges:        ${EGRESS_DESTINATION_RANGES}
Dry run:                         ${DRY_RUN:-false}
SUMMARY

step "1" "Create independent base resources"
log "Creating global network firewall policy"
run gcloud compute network-firewall-policies create "${CONSUMER_FW_POLICY}" \
  --global \
  --project="${PROJECT_ID}"

log "Creating intercept endpoint group"
run gcloud beta network-security intercept-endpoint-groups create "${ENDPOINT_GROUP}" \
  --location="${LOCATION}" \
  --intercept-deployment-group="${INTERCEPT_DEPLOYMENT_GROUP}" \
  --project="${PROJECT_ID}" \
  --no-async

step "2" "Associate base resources with the consumer VPC"
log "Associating firewall policy with consumer VPC"
run gcloud compute network-firewall-policies associations create \
  --name="${CONSUMER_FW_POLICY_ASSOC}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --network="${CONSUMER_NETWORK}" \
  --project="${PROJECT_ID}"

log "Associating intercept endpoint group with consumer VPC"
run gcloud beta network-security intercept-endpoint-group-associations create "${ENDPOINT_GROUP_ASSOCIATION}" \
  --location="${LOCATION}" \
  --intercept-endpoint-group="${ENDPOINT_GROUP_RESOURCE}" \
  --network="${CONSUMER_NETWORK}" \
  --project="${PROJECT_ID}" \
  --no-async

step "3" "Create organization-level security profile resources"
log "Creating custom intercept security profile"
run gcloud beta network-security security-profiles custom-intercept create "${SECURITY_PROFILE}" \
  --location="${LOCATION}" \
  --organization="${ORGANIZATION_ID}" \
  --intercept-endpoint-group="${ENDPOINT_GROUP_RESOURCE}" \
  --billing-project="${BILLING_PROJECT_ID}" \
  --no-async

log "Creating security profile group"
run gcloud beta network-security security-profile-groups create "${SECURITY_PROFILE_GROUP}" \
  --location="${LOCATION}" \
  --organization="${ORGANIZATION_ID}" \
  --custom-intercept-profile="${SECURITY_PROFILE}" \
  --billing-project="${BILLING_PROJECT_ID}" \
  --no-async

step "4" "Create firewall policy rules that apply the security profile group"
log "Creating ingress firewall policy rule"
run gcloud compute network-firewall-policies rules create "${INGRESS_RULE_PRIORITY}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --action=apply_security_profile_group \
  --security-profile-group="${SECURITY_PROFILE_GROUP_RESOURCE}" \
  --direction=INGRESS \
  --layer4-configs=all \
  --src-ip-ranges="${INGRESS_SOURCE_RANGES}" \
  "${LOGGING_FLAG[@]}" \
  --project="${PROJECT_ID}"

log "Creating egress firewall policy rule"
run gcloud compute network-firewall-policies rules create "${EGRESS_RULE_PRIORITY}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --action=apply_security_profile_group \
  --security-profile-group="${SECURITY_PROFILE_GROUP_RESOURCE}" \
  --direction=EGRESS \
  --layer4-configs=all \
  --dest-ip-ranges="${EGRESS_DESTINATION_RANGES}" \
  "${LOGGING_FLAG[@]}" \
  --project="${PROJECT_ID}"

log "Deployment complete"
cat <<NEXT

Validate with:
  gcloud beta network-security intercept-endpoint-groups describe ${ENDPOINT_GROUP} --location=${LOCATION} --project=${PROJECT_ID}
  gcloud beta network-security intercept-endpoint-group-associations describe ${ENDPOINT_GROUP_ASSOCIATION} --location=${LOCATION} --project=${PROJECT_ID}
  gcloud beta network-security security-profile-groups describe ${SECURITY_PROFILE_GROUP} --location=${LOCATION} --organization=${ORGANIZATION_ID} --billing-project=${BILLING_PROJECT_ID}
  gcloud compute network-firewall-policies rules list --firewall-policy=${CONSUMER_FW_POLICY} --global-firewall-policy --project=${PROJECT_ID}
NEXT
