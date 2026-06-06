#!/usr/bin/env bash
# =============================================================================
# One-shot network bootstrap for the local compose network.
#
# Solves Corda's "chicken and egg": before any node can start it needs a common
# network trust root, network-parameters, and every peer's NodeInfo. The
# bootstrapper generates all of that offline (dev identities, no doorman/network
# map server required) and distributes it into each node's base directory.
#
# Runs as root so it can populate the (root-owned, empty) named volumes, then
# hands ownership to the unprivileged corda uid the nodes run as. Idempotent:
# re-running after a successful bootstrap is a no-op.
# =============================================================================
set -euo pipefail

ROOT="${BOOTSTRAP_DIR:-/bootstrap}"
SRC="${INPUT_DIR:-/input}"
NODES="${NODES:-notary node1 node2}"
CORDA_UID="${CORDA_UID:-1000}"
CORDA_GID="${CORDA_GID:-1000}"

log() { printf '[bootstrap] %s\n' "$*"; }

# Idempotency: if every node already has network-parameters, nothing to do.
already=true
for n in ${NODES}; do
    [[ -f "${ROOT}/${n}/network-parameters" ]] || already=false
done
if ${already}; then
    log "network already bootstrapped — skipping"
    exit 0
fi

log "seeding node.conf for: ${NODES}"
for n in ${NODES}; do
    mkdir -p "${ROOT}/${n}/persistence"
    cp "${SRC}/${n}/node.conf" "${ROOT}/${n}/node.conf"
done

log "running network bootstrapper over ${ROOT}"
# shellcheck disable=SC2086
java ${JAVA_OPTS:-} -jar /opt/corda/corda-bootstrapper.jar --dir "${ROOT}"

log "handing ownership of ${ROOT} to ${CORDA_UID}:${CORDA_GID}"
chown -R "${CORDA_UID}:${CORDA_GID}" "${ROOT}"

log "bootstrap complete"
