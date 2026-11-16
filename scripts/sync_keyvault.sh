#!/usr/bin/env bash
# Synchronize an explicit allowlist of GitHub values to Azure Key Vault.
#
# GitHub-owned values only. Do NOT add credentials that Key Vault / the platform team owns, such as the
# Airflow-to-Databricks connection (airflow-connections-databricks-default): syncing those from GitHub
# would overwrite rotated values with stale ones.
#
# Values already identical in Key Vault are left alone, so every-deploy sync does not create a new
# secret version each time.

set -euo pipefail

: "${KEYVAULT_NAME:?Missing KEYVAULT_NAME}"
: "${FINANCE_API_KEY:?Missing FINANCE_API_KEY}"
: "${FINANCE_ENDPOINT:?Missing FINANCE_ENDPOINT}"

# No direct secret values in command line arguments, logs, artifacts or source.
umask 077
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

written=0
unchanged=0

write_secret() {
  local name="$1" value="$2" existing
  existing="$(az keyvault secret show \
    --vault-name "$KEYVAULT_NAME" \
    --name "$name" \
    --query value \
    --output tsv 2>/dev/null || true)"

  if [ "$existing" = "$value" ]; then
    echo "Unchanged:    $name"
    unchanged=$((unchanged + 1))
    return 0
  fi

  printf '%s' "$value" > "$tmpfile"
  az keyvault secret set \
    --vault-name "$KEYVAULT_NAME" \
    --name "$name" \
    --file "$tmpfile" \
    --output none
  : > "$tmpfile"
  echo "Synchronized: $name"
  written=$((written + 1))
}

# Explicit allowlist. Add new entries only after review (see CODEOWNERS).
write_secret 'finance-api-key' "$FINANCE_API_KEY"
write_secret 'finance-endpoint' "$FINANCE_ENDPOINT"

echo "Key Vault sync done: ${written} written, ${unchanged} unchanged (vault: ${KEYVAULT_NAME})"
