#!/usr/bin/env bash
# Classify what changed between two commits.
#
# Plain `git diff` on purpose: path-filter actions such as dorny/paths-filter are not on the
# client's enterprise allow-list.
#
#   Usage: scripts/detect_changes.sh <base_sha> <head_sha>
#
#   Env:   THREE_DOT=true               diff BASE...HEAD (pull requests) instead of BASE..HEAD (pushes)
#          CI_CHANGES_TRIGGER_ALL=true  a change under .github/workflows or scripts marks everything as changed (PR CI)
#
# Outputs (stdout and $GITHUB_OUTPUT):
#   base_usable          false when there is no usable base commit (new branch, manual run, force push)
#   databricks           something under databricks/ changed
#   orchestration        something under orchestration/ changed
#   orchestration_image  something under orchestration/ other than dags/ and tests/ changed
#                        (Dockerfile, requirements.txt, packages.txt ...): a DAG-only deploy is not enough
#   keyvault             anything under keyvault/ changed
#   keyvault_request     keyvault/sync-request.yml changed
#   has_changes          databricks, orchestration or keyvault changed
#
# With no usable base commit everything is treated as changed (nothing is silently skipped),
# except keyvault_request, which stays false: an initial push never authorizes a sync by itself.
#
# Edit the case patterns below if the folder layout changes.

set -euo pipefail

BASE="${1:-}"
HEAD="${2:-HEAD}"
ZERO=0000000000000000000000000000000000000000

BASE_USABLE=true
DATABRICKS=false
ORCH=false
ORCH_IMAGE=false
KEYVAULT=false
KV_REQUEST=false
CI_CHANGED=false

if [ -z "$BASE" ] || [ "$BASE" = "$ZERO" ] || ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  echo "No usable base commit: treating everything as changed."
  BASE_USABLE=false
  DATABRICKS=true
  ORCH=true
  ORCH_IMAGE=true
  KEYVAULT=true
else
  RANGE="${BASE}..${HEAD}"
  if [ "${THREE_DOT:-false}" = "true" ]; then
    RANGE="${BASE}...${HEAD}"
  fi
  echo "Diff range: $RANGE"

  CHANGED="$(git diff --name-only "$RANGE")"
  echo "Changed files:"
  printf '%s\n' "$CHANGED" | sed 's/^/  /'

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      databricks/*)
        DATABRICKS=true ;;
      orchestration/dags/*|orchestration/tests/*)
        ORCH=true ;;
      orchestration/*)
        ORCH=true
        ORCH_IMAGE=true ;;
      keyvault/sync-request.yml)
        KEYVAULT=true
        KV_REQUEST=true ;;
      keyvault/*)
        KEYVAULT=true ;;
      .github/workflows/*|scripts/*)
        CI_CHANGED=true ;;
    esac
  done <<< "$CHANGED"

  if [ "${CI_CHANGES_TRIGGER_ALL:-false}" = "true" ] && [ "$CI_CHANGED" = "true" ]; then
    echo "CI configuration changed: validating everything."
    DATABRICKS=true
    ORCH=true
    KEYVAULT=true
  fi
fi

HAS_CHANGES=false
if [ "$DATABRICKS" = "true" ] || [ "$ORCH" = "true" ] || [ "$KEYVAULT" = "true" ]; then
  HAS_CHANGES=true
fi

{
  echo "base_usable=$BASE_USABLE"
  echo "databricks=$DATABRICKS"
  echo "orchestration=$ORCH"
  echo "orchestration_image=$ORCH_IMAGE"
  echo "keyvault=$KEYVAULT"
  echo "keyvault_request=$KV_REQUEST"
  echo "has_changes=$HAS_CHANGES"
} | tee -a "${GITHUB_OUTPUT:-/dev/null}"
