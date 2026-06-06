#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh — liveness/readiness probe for a Corda node.
#
# A Corda node binds its RPC port only after it has fully started (loaded
# CorDapps, run DB migrations, registered with the network). So "RPC port is
# accepting TCP connections" is a good readiness signal. We deliberately do not
# open an RPC session here (that would need credentials); a TCP connect is
# enough and cheap.
# =============================================================================
set -euo pipefail
PORT="${RPC_PORT:-10201}"
if timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/${PORT}" 2>/dev/null; then
    exit 0
fi
echo "Corda RPC port ${PORT} not accepting connections yet" >&2
exit 1
