#!/usr/bin/env bash
# Creates the Azure Storage Account used as the Terraform remote state backend.
# Run this once per subscription before the first terraform init.
#
# Required env vars:
#   AZURE_LOCATION          Azure region (default: westeurope)
#   TF_STATE_RG             Resource group name for state storage (default: rg-corda-tfstate)
#   TF_STATE_SA             Storage account name (default: stcordatfstate, must be globally unique)
#   TF_STATE_CONTAINER      Blob container name (default: tfstate)
set -euo pipefail

LOCATION="${AZURE_LOCATION:-westeurope}"
RG="${TF_STATE_RG:-rg-corda-tfstate}"
SA="${TF_STATE_SA:-stcordatfstate}"
CONTAINER="${TF_STATE_CONTAINER:-tfstate}"

az group create \
  --name "$RG" \
  --location "$LOCATION" \
  --only-show-errors

az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --only-show-errors

az storage container create \
  --name "$CONTAINER" \
  --account-name "$SA" \
  --only-show-errors

az storage account blob-service-properties update \
  --account-name "$SA" \
  --resource-group "$RG" \
  --enable-versioning true \
  --only-show-errors

printf '\nTerraform state backend is ready.\n'
printf 'Next steps:\n'
printf '  terraform init -backend-config=environments/dev-backend.tfvars\n'
printf '  terraform apply -var-file=environments/dev.tfvars\n'
