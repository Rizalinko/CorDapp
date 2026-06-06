#!/usr/bin/env bash
# =============================================================================
# This script renders a Corda node.conf (HOCON) from environment vars.
#
# This is the SINGLE source of truth for turning parameters into a node.conf.
# In Docker / docker-compose: the entrypoint calls this when no node.conf
# has been mounted, so a node is fully configured from env vars alone.

# Output goes to stdout. Passwords are read from env (never baked into images).
# =============================================================================
set -euo pipefail

# Immutable distribution dir (jars/drivers/baked CorDapps) vs. the node base
# directory (volume/PVC). Kept separate so a mount never shadows the jars.
CORDA_HOME="${CORDA_HOME:-/opt/corda}"
CORDA_BASE_DIR="${CORDA_BASE_DIR:-/var/lib/corda}"

# identity
NODE_ROLE="${NODE_ROLE:-node}"                 # node | notary
MY_LEGAL_NAME="${MY_LEGAL_NAME:?MY_LEGAL_NAME is required (X.500, e.g. 'O=Node1,L=London,C=GB')}"

# networking
P2P_PORT="${P2P_PORT:-10200}"
RPC_PORT="${RPC_PORT:-10201}"
RPC_ADMIN_PORT="${RPC_ADMIN_PORT:-10202}"
P2P_ADDRESS="${P2P_ADDRESS:-${HOSTNAME}:${P2P_PORT}}"
DETECT_PUBLIC_IP="${DETECT_PUBLIC_IP:-false}"  # must be false inside containers

# security
DEV_MODE="${DEV_MODE:-true}"
RPC_USER="${RPC_USER:-corda}"
RPC_PASSWORD="${RPC_PASSWORD:-}"
KEY_STORE_PASSWORD="${KEY_STORE_PASSWORD:-}"
TRUST_STORE_PASSWORD="${TRUST_STORE_PASSWORD:-}"

# database
DB_TYPE="${DB_TYPE:-h2}"                        # h2 | postgresql

# compatibility zone (production doorman/network-map)
# Leave empty when bootstrapping with the network bootstrapper (dev/eval).
COMPATIBILITY_ZONE_URL="${COMPATIBILITY_ZONE_URL:-}"
DOORMAN_URL="${DOORMAN_URL:-}"
NETWORK_MAP_URL="${NETWORK_MAP_URL:-}"

# ---------------------------------------------------------------------------
# Emit node.conf
# ---------------------------------------------------------------------------
emit() { printf '%s\n' "$1"; }

emit "myLegalName = \"${MY_LEGAL_NAME}\""
emit "p2pAddress = \"${P2P_ADDRESS}\""
emit "detectPublicIp = ${DETECT_PUBLIC_IP}"
emit "devMode = ${DEV_MODE}"
# Load JDBC drivers from the immutable distribution, and CorDapps from both the
# mutable base dir (mounted/extra) and the image's baked dir (Part 4 artifact).
emit "jarDirs = [ \"${CORDA_HOME}/drivers\" ]"
emit "cordappDirectories = [ \"${CORDA_BASE_DIR}/cordapps\", \"${CORDA_HOME}/cordapps-baked\" ]"
# In production we still want the node to keep running if a peer's CRL endpoint
# is briefly unreachable; tighten to HARD_FAIL once your PKI/CRL is stable.
emit "crlCheckSoftFail = true"
emit ""
emit "rpcSettings {"
emit "    address = \"0.0.0.0:${RPC_PORT}\""
emit "    adminAddress = \"0.0.0.0:${RPC_ADMIN_PORT}\""
emit "}"
emit ""

# Keystore passwords (omitted in devMode → Corda uses the well-known dev pass)
if [[ "${DEV_MODE}" != "true" ]]; then
    : "${KEY_STORE_PASSWORD:?KEY_STORE_PASSWORD is required when devMode=false}"
    : "${TRUST_STORE_PASSWORD:?TRUST_STORE_PASSWORD is required when devMode=false}"
    emit "keyStorePassword = \"${KEY_STORE_PASSWORD}\""
    emit "trustStorePassword = \"${TRUST_STORE_PASSWORD}\""
    emit ""
fi

# RPC users
if [[ -z "${RPC_PASSWORD}" ]]; then
    if [[ "${DEV_MODE}" == "true" ]]; then
        RPC_PASSWORD="dev-rpc-password"
    else
        echo "RPC_PASSWORD is required when devMode=false" >&2; exit 1
    fi
fi
emit "rpcUsers = ["
emit "    { username = \"${RPC_USER}\", password = \"${RPC_PASSWORD}\", permissions = [\"ALL\"] }"
emit "]"
emit ""

# Database
case "${DB_TYPE}" in
  h2)
    emit "dataSourceProperties {"
    emit "    dataSourceClassName = \"org.h2.jdbcx.JdbcDataSource\""
    emit "    dataSource.url = \"jdbc:h2:file:\${baseDirectory}/persistence/persistence;DB_CLOSE_ON_EXIT=FALSE;WRITE_DELAY=0;LOCK_TIMEOUT=10000\""
    emit "    dataSource.user = \"sa\""
    emit "    dataSource.password = \"\""
    emit "}"
    ;;
  postgresql)
    DB_HOST="${DB_HOST:?DB_HOST is required for postgresql}"
    DB_PORT="${DB_PORT:-5432}"
    DB_NAME="${DB_NAME:?DB_NAME is required for postgresql}"
    DB_USER="${DB_USER:?DB_USER is required for postgresql}"
    DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required for postgresql}"
    DB_SCHEMA="${DB_SCHEMA:-corda}"
    emit "dataSourceProperties {"
    emit "    dataSourceClassName = \"org.postgresql.ds.PGSimpleDataSource\""
    emit "    dataSource.url = \"jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?currentSchema=${DB_SCHEMA}\""
    emit "    dataSource.user = \"${DB_USER}\""
    emit "    dataSource.password = \"${DB_PASSWORD}\""
    emit "}"
    ;;
  *)
    echo "Unsupported DB_TYPE='${DB_TYPE}' (expected h2|postgresql)" >&2; exit 1
    ;;
esac
emit ""

# Notary role
if [[ "${NODE_ROLE}" == "notary" ]]; then
    emit "notary {"
    emit "    validating = ${NOTARY_VALIDATING:-false}"
    emit "}"
    emit ""
fi

# Compatibility zone (production with a doorman + network map service).
# Mutually exclusive with bootstrapper-supplied network-parameters.
if [[ -n "${COMPATIBILITY_ZONE_URL}" ]]; then
    emit "compatibilityZoneURL = \"${COMPATIBILITY_ZONE_URL}\""
elif [[ -n "${DOORMAN_URL}" && -n "${NETWORK_MAP_URL}" ]]; then
    emit "networkServices {"
    emit "    doormanURL = \"${DOORMAN_URL}\""
    emit "    networkMapURL = \"${NETWORK_MAP_URL}\""
    emit "}"
fi
