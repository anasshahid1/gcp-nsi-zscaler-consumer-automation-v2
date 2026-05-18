#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./destroy.sh <config.env>

Deletes customer-side resources created by deploy.sh.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

log() {
  echo "==> $*"
}

run() {
  echo "+ $*"
  if [[ "${DRY_RUN:-false}" != "true" ]]; then
    "$@" || true
  fi
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

: "${DEPLOY_KEY:?Missing DEPLOY_KEY}"
: "${PROJECT_ID:?Missing PROJECT_ID}"
: "${ORGANIZATION_ID:?Missing ORGANIZATION_ID}"
: "${BILLING_PROJECT_ID:?Missing BILLING_PROJECT_ID}"
: "${LOCATION:?Missing LOCATION}"
: "${INGRESS_RULE_PRIORITY:?Missing INGRESS_RULE_PRIORITY}"
: "${EGRESS_RULE_PRIORITY:?Missing EGRESS_RULE_PRIORITY}"

default_if_empty CONSUMER_FW_POLICY "${DEPLOY_KEY}-consumer-policy"
default_if_empty CONSUMER_FW_POLICY_ASSOCIATION "${CONSUMER_FW_POLICY_ASSOC:-}"
default_if_empty CONSUMER_FW_POLICY_ASSOCIATION "${DEPLOY_KEY}-consumer-policy-association"
default_if_empty SECURITY_PROFILE "${DEPLOY_KEY}-custom-intercept-profile"
default_if_empty SECURITY_PROFILE_GROUP "${DEPLOY_KEY}-security-profile-group"
default_if_empty ENDPOINT_GROUP "${DEPLOY_KEY}-intercept-endpoint-group"
default_if_empty ENDPOINT_GROUP_ASSOCIATION "${DEPLOY_KEY}-intercept-endpoint-group-association"

log "Deleting firewall policy rules"
run gcloud compute network-firewall-policies rules delete "${INGRESS_RULE_PRIORITY}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --project="${PROJECT_ID}" \
  --quiet

run gcloud compute network-firewall-policies rules delete "${EGRESS_RULE_PRIORITY}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --project="${PROJECT_ID}" \
  --quiet

log "Deleting security profile group"
run gcloud beta network-security security-profile-groups delete "${SECURITY_PROFILE_GROUP}" \
  --location="${LOCATION}" \
  --organization="${ORGANIZATION_ID}" \
  --billing-project="${BILLING_PROJECT_ID}" \
  --quiet

log "Deleting custom intercept security profile"
run gcloud beta network-security security-profiles custom-intercept delete "${SECURITY_PROFILE}" \
  --location="${LOCATION}" \
  --organization="${ORGANIZATION_ID}" \
  --billing-project="${BILLING_PROJECT_ID}" \
  --quiet

log "Deleting intercept endpoint group association"
run gcloud beta network-security intercept-endpoint-group-associations delete "${ENDPOINT_GROUP_ASSOCIATION}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --quiet

log "Deleting intercept endpoint group"
run gcloud beta network-security intercept-endpoint-groups delete "${ENDPOINT_GROUP}" \
  --location="${LOCATION}" \
  --project="${PROJECT_ID}" \
  --quiet

log "Deleting firewall policy association"
run gcloud compute network-firewall-policies associations delete \
  --name="${CONSUMER_FW_POLICY_ASSOCIATION}" \
  --firewall-policy="${CONSUMER_FW_POLICY}" \
  --global-firewall-policy \
  --project="${PROJECT_ID}" \
  --quiet

log "Deleting firewall policy"
run gcloud compute network-firewall-policies delete "${CONSUMER_FW_POLICY}" \
  --global \
  --project="${PROJECT_ID}" \
  --quiet

log "Cleanup complete"
