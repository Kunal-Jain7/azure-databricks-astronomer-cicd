# Azure Databricks + Astronomer CI/CD starter

A GitHub domain repository with long-lived `DEV`, `UAT`, `PROD` branches that deploys **Azure Databricks** (asset bundle) and **Astronomer Managed Airflow**, with **Azure Key Vault** for secrets. It extends the other teams' Databricks starter and keeps its structure. This is a scaffold: it has been syntax- and logic-tested locally, but not run against real workspaces, Astronomer or Key Vault.

## Layout

```
.github/workflows/
  ci.yml                    PR checks for both domains, ends in "CI Gate"
  databricks-deploy.yml     plan -> approve -> [Key Vault sync] -> bundle deploy
  astronomer-deploy.yml     plan -> approve -> [Key Vault sync] -> Astronomer deploy
  keyvault-sync.yml         reusable sync job (called by the two deploys and the manual workflow)
  sync-keyvault-manual.yml  manual sync, type SYNC
.github/CODEOWNERS         replace the placeholder team
databricks/                 bundle, wheel source, tests (the starter's finance example)
orchestration/              Astro project: Dockerfile, requirements, dags/, tests/
keyvault/sync-request.yml   bump `revision` to request a sync
scripts/
  detect_changes.sh         native git diff change detection (no third-party path-filter action)
  resolve_plan.sh           target, deploy, deploy type and sync decisions
  sync_keyvault.sh          allowlisted GitHub -> Key Vault sync, skips unchanged values
```

Deploy Databricks first, then Astronomer: the DAG looks the Databricks job up by name at run time.

## What changed compared with the starter

- **Astronomer deployment added**, using `astronomer/deploy-action@v0.17.0`. `deploy-type` is computed from the whole push range (DAG-only changes -> `dags-only`; Dockerfile, requirements or packages changes -> `image-and-dags`), because the action's `infer` mode only looks at the latest commit.
- **Key Vault sync mode** via the repository variable `KEYVAULT_SYNC_MODE`:
  - `always` (default): sync whenever a deploy runs or the request file changes. This is what the client's diagram shows.
  - `on-request`: the starter's behaviour, sync only when `keyvault/sync-request.yml` changes in a push.
- **Single approval per run.** Approval is a separate job on environment `<env>-approval`; the sync and deploy jobs use the plain `<env>` environment. Put the required reviewers on `dev-approval`, `uat-approval`, `prod-approval` only, otherwise PROD asks twice.
- **CI Gate** checks every job, including the secret scan and change detection. A failed or wrongly skipped job fails the gate.
- **Client conventions**: `RUNNER_LABEL` runner, `PYTHON_IMAGE` container for Python jobs, gitleaks v8.18.4, no `dorny/paths-filter`. Add the company root CA step as the first step of each job on the client runners (marked in the workflow comments).
- **Wheel version** is stamped with the commit SHA, so the same commit has the same version in every environment.
- **Job cluster** uses `data_security_mode: SINGLE_USER` for Unity Catalog.
- Key Vault sync only touches the allowlist in `scripts/sync_keyvault.sh`, compares before writing, and never logs values.

## Variables and secrets

Repository variables (optional): `RUNNER_LABEL`, `PYTHON_IMAGE` (Python 3.10 to 3.12), `KEYVAULT_SYNC_MODE`.

Per environment (`dev`, `uat`, `prod`):

| Name | Kind | Used for |
|---|---|---|
| `DATABRICKS_HOST`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CATALOG`, `DATABRICKS_SCHEMA` | variable | bundle deploy |
| `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_KEYVAULT_NAME` | variable | Key Vault sync (Entra OIDC) |
| `FINANCE_ENDPOINT` | variable | example synced value |
| `FINANCE_API_KEY` | secret | example synced value (change the allowlist to approved names) |
| `ASTRO_DEPLOYMENT_ID` | variable | Astronomer deployment for that environment |
| `ASTRO_API_TOKEN` | secret | deployment-scoped Astronomer API token |

Also create `dev-approval`, `uat-approval`, `prod-approval` environments (reviewers there; restrict each environment to its branch).

## Setup

1. **Databricks service principal for CI** (account level) with workspace and job permissions, plus a GitHub OIDC federation policy: issuer `https://token.actions.githubusercontent.com`, audience = your Databricks account ID, subject `repo:<org>/<repo>:environment:<env>`. Repositories created, renamed or transferred from 15 July 2026 use the immutable subject format, so copy the exact subject from the token claims.
2. **Entra app registration for Key Vault sync** with federated credentials `repo:<org>/<repo>:environment:<env>` and Key Vault Secrets Officer on the target vault.
3. **Astronomer**: one deployment per environment, a deployment API token stored as `ASTRO_API_TOKEN`, DAG-only deploys enabled on the deployments.
4. **Airflow to Databricks authentication (recommended)**: a dedicated Databricks service principal for Airflow, OAuth M2M, scoped to run the pipeline jobs only.
   - Store the connection JSON in Key Vault as `airflow-connections-databricks-default` (see `orchestration/.env.example`). The platform team owns this secret; it is **not** in the sync allowlist.
   - Set on each Astronomer deployment: `AIRFLOW__SECRETS__BACKEND`, `AIRFLOW__SECRETS__BACKEND_KWARGS`, `ENV_NAME` (`dev`/`uat`/`prod`). The deployment needs a way to read the vault (a Key Vault Secrets User identity for Airflow).
   - Grant that principal `CAN_MANAGE_RUN` on the job: uncomment the `permissions` block in `databricks/resources/finance_job.yml` (check the permission name against your CLI version).
   - Longer term, move to workload identity (`use_default_azure_credential`) so no secret exists.
5. Do a first controlled sync with `sync-keyvault-manual.yml`, then push to `DEV`.

## Open points to confirm with the client

- **Runners**: the ARC runners are on AWS. Confirm they have the Azure CLI, `jq`, Docker (image deploys) and network access to Azure, Databricks and Astronomer.
- **Allow-list**: confirm `azure/login`, `databricks/setup-cli`, `astronomer/deploy-action`, `actions/setup-python` are permitted, and pin all actions to reviewed commit SHAs. `databricks/setup-cli` is on `@main` here; I could not verify a release tag.
- **Astronomer auth**: API tokens only; no OIDC option was found in Astronomer's docs.
- **Key Vault sync default** is `always`; switch to `on-request` if overwriting newer vault values is a concern.
- **dbt** (the earlier sample's `transformation/` folder) is not included in this starter, nor are dbt baseline manifests.
- **Development vs migration tracks**: this covers one track.
- Not built here: build-once-promote artifact registry, Unity Catalog/Key Vault/network provisioning (central IaC).

## Local checks

```
python -m pytest databricks/tests
cd databricks && python -m build --wheel
# orchestration tests need Airflow 2.10.4 installed with the official constraints file (Python 3.10 to 3.12)
python -m pytest orchestration/tests
```
