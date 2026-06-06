#!/usr/bin/env bash
# =============================================================================
# wait-healthy.sh — block until the given compose services report 'healthy'.
# Used by `make network-wait` locally and by the CI smoke test.
#
#   TIMEOUT=600 ./scripts/wait-healthy.sh notary node1 node2
# =============================================================================
set -euo pipefail

services=("$@")
if [[ ${#services[@]} -eq 0 ]]; then
    services=(notary node1 node2)
fi

timeout="${TIMEOUT:-600}"
deadline=$(( $(date +%s) + timeout ))

echo "Waiting up to ${timeout}s for: ${services[*]}"
while true; do
    all_healthy=true
    for s in "${services[@]}"; do
        cid="$(docker compose ps -q "${s}" 2>/dev/null || true)"
        if [[ -z "${cid}" ]]; then
            echo "  ${s}: (not created yet)"; all_healthy=false; continue
        fi
        status="$(docker inspect -f '{{ if .State.Health }}{{ .State.Health.Status }}{{ else }}{{ .State.Status }}{{ end }}' "${cid}")"
        echo "  ${s}: ${status}"
        case "${status}" in
            healthy)        : ;;
            exited|dead)    echo "FAILED: ${s} is ${status}"; exit 1 ;;
            *)              all_healthy=false ;;
        esac
    done
    if ${all_healthy}; then
        echo "All services healthy."
        exit 0
    fi
    if (( $(date +%s) > deadline )); then
        echo "TIMEOUT after ${timeout}s waiting for services to become healthy."
        exit 1
    fi
    sleep 10
done
