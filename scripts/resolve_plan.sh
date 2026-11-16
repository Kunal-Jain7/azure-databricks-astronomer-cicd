#!/usr/bin/env bash
# Resolve the target environment and the deploy / Key Vault sync decisions for ONE deploy workflow.
#
#   Env in:  DOMAIN                databricks | orchestration
#            REF_NAME              branch name (DEV, UAT, PROD)
#            EVENT_NAME            push | workflow_dispatch
#            KEYVAULT_SYNC_MODE    always (default) | on-request
#            CHG_DATABRICKS, CHG_ORCHESTRATION, CHG_IMAGE, CHG_REQUEST, BASE_USABLE
#                                  outputs of scripts/detect_changes.sh
#
#   Out ($GITHUB_OUTPUT): target, deploy, deploy_type, sync
#
# Key Vault sync modes
#   always      sync the allowlisted values whenever this workflow deploys, or when the sync request changed.
#               Matches the client's "New Workflow Flow" (sync on every deploy).
#   on-request  sync only when keyvault/sync-request.yml changed within the push range (never on the first push
#               of a branch and never on a manual run). Avoids overwriting newer Key Vault values.
#
# deploy_type is for Astronomer: dags-only when only DAG files changed, otherwise image-and-dags.
# It is decided here from the complete push range, because the deploy action's own "infer" mode
# looks at the latest commit only.

set -euo pipefail

: "${DOMAIN:?DOMAIN is required}"
: "${REF_NAME:?REF_NAME is required}"
: "${EVENT_NAME:?EVENT_NAME is required}"

case "$REF_NAME" in
  DEV)  TARGET=dev ;;
  UAT)  TARGET=uat ;;
  PROD) TARGET=prod ;;
  *)    echo "Unsupported branch: $REF_NAME" >&2; exit 1 ;;
esac

case "$DOMAIN" in
  databricks)    DEPLOY="${CHG_DATABRICKS:-false}" ;;
  orchestration) DEPLOY="${CHG_ORCHESTRATION:-false}" ;;
  *)             echo "Unknown DOMAIN: $DOMAIN" >&2; exit 1 ;;
esac

DEPLOY_TYPE=none
if [ "$DOMAIN" = "orchestration" ] && [ "$DEPLOY" = "true" ]; then
  if [ "${CHG_IMAGE:-false}" = "true" ]; then
    DEPLOY_TYPE=image-and-dags
  else
    DEPLOY_TYPE=dags-only
  fi
fi

MODE="${KEYVAULT_SYNC_MODE:-always}"
SYNC=false
case "$MODE" in
  always)
    if [ "$DEPLOY" = "true" ] || [ "${CHG_REQUEST:-false}" = "true" ]; then
      SYNC=true
    fi
    ;;
  on-request)
    if [ "$EVENT_NAME" = "push" ] && [ "${BASE_USABLE:-false}" = "true" ] && [ "${CHG_REQUEST:-false}" = "true" ]; then
      SYNC=true
    fi
    ;;
  *)
    echo "Unsupported KEYVAULT_SYNC_MODE: $MODE (use always or on-request)" >&2
    exit 1
    ;;
esac

{
  echo "target=$TARGET"
  echo "deploy=$DEPLOY"
  echo "deploy_type=$DEPLOY_TYPE"
  echo "sync=$SYNC"
} | tee -a "${GITHUB_OUTPUT:-/dev/null}"

echo "Domain: $DOMAIN | target: $TARGET | deploy: $DEPLOY ($DEPLOY_TYPE) | sync: $SYNC (mode: $MODE)"
