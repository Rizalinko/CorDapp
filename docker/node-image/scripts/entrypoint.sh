#!/usr/bin/env bash
# =============================================================================
# Modes (first argument):
#   node       (default) run the Corda node. Generates node.conf from env vars
#              only if one has not already been mounted (Helm/ConfigMap path).
#   bootstrap  run the network bootstrapper over CORDA_HOME (used by the
#              one-shot bootstrap job in compose / k8s).
#   config     print the node.conf that would be generated, then exit.
#   <other>    exec the given command verbatim (debug escape hatch).
# =============================================================================
set -euo pipefail

# CORDA_HOME = immutable distribution (jars, bin, drivers).
# CORDA_BASE_DIR = mutable node base directory (volume/PVC): certificates,
# persistence, cordapps, network-parameters, node.conf, logs.
CORDA_HOME="${CORDA_HOME:-/opt/corda}"
CORDA_BASE_DIR="${CORDA_BASE_DIR:-/var/lib/corda}"
cd "${CORDA_BASE_DIR}"

log() { printf '[entrypoint] %s\n' "$*"; }

# A fresh Docker volume or Kubernetes PVC is empty, the image's base-dir
# skeleton is NOT copied into it. Recreate the directories the node needs so we
# work identically on first boot and on restart.
ensure_skeleton() {
    mkdir -p \
        "${CORDA_BASE_DIR}/cordapps" \
        "${CORDA_BASE_DIR}/certificates" \
        "${CORDA_BASE_DIR}/persistence" \
        "${CORDA_BASE_DIR}/logs" \
        "${CORDA_BASE_DIR}/additional-node-infos" \
        "${CORDA_BASE_DIR}/.capsule"
}

run_node() {
    ensure_skeleton
    # node.conf from env on every start, so a ConfigMap/Secret change picked up
    # by a rollout always takes effect. Default (compose, bootstrapped, mounted)
    # preserves an existing node.conf verbatim.
    if [[ -f "${CORDA_BASE_DIR}/node.conf" && "${REGEN_CONFIG:-false}" != "true" ]]; then
        log "Using existing node.conf (mounted or previously generated)"
    else
        log "Generating node.conf from environment (REGEN_CONFIG=${REGEN_CONFIG:-false})"
        "${CORDA_HOME}/bin/generate-config.sh" > "${CORDA_BASE_DIR}/node.conf"
    fi

    # Print effective config with secrets masked, to aid debugging.
    log "Effective node.conf:"
    sed -E 's/(password[^=]*=).*/\1 ***/I' "${CORDA_BASE_DIR}/node.conf" | sed 's/^/    /'

    log "Starting Corda ${CORDA_VERSION:-?} node"
    # shellcheck disable=SC2086  # JAVA_OPTS is intentionally word-split
    exec java ${JAVA_OPTS:-} -jar "${CORDA_HOME}/corda.jar" \
        --base-directory "${CORDA_BASE_DIR}" \
        "$@"
}

run_bootstrap() {
    log "Running network bootstrapper"
    # shellcheck disable=SC2086
    exec java ${JAVA_OPTS:-} -jar "${CORDA_HOME}/corda-bootstrapper.jar" "$@"
}

mode="${1:-node}"
case "${mode}" in
    node)       shift || true; run_node "$@" ;;
    bootstrap)  shift;         run_bootstrap "$@" ;;
    config)     exec "${CORDA_HOME}/bin/generate-config.sh" ;;
    migrate)
        # Run DB schema migrations (required before first start on PostgreSQL).
        shift
        log "Running database migration scripts"
        # shellcheck disable=SC2086
        exec java ${JAVA_OPTS:-} -jar "${CORDA_HOME}/corda.jar" \
            --base-directory "${CORDA_BASE_DIR}" \
            run-migration-scripts --core-schemas --app-schemas "$@"
        ;;
    *)          log "Executing verbatim: $*"; exec "$@" ;;
esac
