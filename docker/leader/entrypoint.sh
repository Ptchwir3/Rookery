#!/bin/sh
# ============================================================================
# Rookery Leader Entrypoint — Dynamic Worker Discovery
# ============================================================================
# Runs a continuous discovery loop. When the worker set changes (node joins,
# pod restarts, evictions), llama-server is gracefully restarted with the
# updated worker list. Also handles crash recovery automatically.
# ============================================================================

set -e

DISCOVERY_INTERVAL="${ROOKERY_DISCOVERY_INTERVAL:-30}"
CURRENT_WORKERS=""
SERVER_PID=""

log() {
    echo "[rookery-leader] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# --------------------------------------------------------------------------
# Signal handling — forward signals to llama-server
# --------------------------------------------------------------------------
cleanup() {
    log "Received shutdown signal"
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log "Stopping llama-server (PID $SERVER_PID)..."
        kill -TERM "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
    fi
    exit 0
}

trap cleanup TERM INT QUIT

# --------------------------------------------------------------------------
# Discover workers via DNS lookup on the headless service
# Returns a sorted, comma-separated list of host:port pairs
# --------------------------------------------------------------------------
discover_workers() {
    if [ -z "$ROOKERY_WORKER_SVC" ]; then
        echo ""
        return
    fi

    WORKER_IPS=$(getent hosts "$ROOKERY_WORKER_SVC" 2>/dev/null | awk '{print $1}' | sort)

    RPC_SERVERS=""
    for IP in $WORKER_IPS; do
        if [ -n "$RPC_SERVERS" ]; then
            RPC_SERVERS="${RPC_SERVERS},"
        fi
        RPC_SERVERS="${RPC_SERVERS}${IP}:${ROOKERY_WORKER_PORT}"
    done

    echo "$RPC_SERVERS"
}

# --------------------------------------------------------------------------
# Start llama-server with the current worker list
# --------------------------------------------------------------------------
start_server() {
    WORKERS="$1"

    ARGS="--model ${ROOKERY_MODEL} \
          --host ${ROOKERY_HOST} \
          --port ${ROOKERY_PORT} \
          --ctx-size ${ROOKERY_CTX_SIZE} \
          --n-gpu-layers ${ROOKERY_N_GPU_LAYERS} \
          --parallel ${ROOKERY_PARALLEL}"

    if [ -n "$WORKERS" ]; then
        ARGS="${ARGS} --rpc ${WORKERS}"
    fi

    if [ -n "${ROOKERY_EXTRA_ARGS}" ]; then
        ARGS="${ARGS} ${ROOKERY_EXTRA_ARGS}"
    fi

    log "Starting llama-server"
    log "  Model:   ${ROOKERY_MODEL}"
    log "  Workers: ${WORKERS:-none (standalone)}"
    log "  API:     http://${ROOKERY_HOST}:${ROOKERY_PORT}"

    llama-server ${ARGS} &
    SERVER_PID=$!
    log "llama-server started (PID $SERVER_PID)"
}

# --------------------------------------------------------------------------
# Stop the running llama-server instance
# --------------------------------------------------------------------------
stop_server() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log "Stopping llama-server (PID $SERVER_PID) for worker update..."
        kill -TERM "$SERVER_PID" 2>/dev/null

        WAIT=0
        while [ $WAIT -lt 30 ] && kill -0 "$SERVER_PID" 2>/dev/null; do
            sleep 1
            WAIT=$((WAIT + 1))
        done

        if kill -0 "$SERVER_PID" 2>/dev/null; then
            log "Graceful shutdown timed out, sending SIGKILL"
            kill -KILL "$SERVER_PID" 2>/dev/null
            wait "$SERVER_PID" 2>/dev/null
        fi

        SERVER_PID=""
        log "llama-server stopped"
    fi
}

# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------
log "Dynamic worker discovery enabled (interval: ${DISCOVERY_INTERVAL}s)"

CURRENT_WORKERS=$(discover_workers)
start_server "$CURRENT_WORKERS"

while true; do
    sleep "$DISCOVERY_INTERVAL"

    # Crash recovery
    if [ -n "$SERVER_PID" ] && ! kill -0 "$SERVER_PID" 2>/dev/null; then
        log "WARNING: llama-server (PID $SERVER_PID) exited unexpectedly"
        SERVER_PID=""
        CURRENT_WORKERS=$(discover_workers)
        log "Restarting with workers: ${CURRENT_WORKERS:-none}"
        start_server "$CURRENT_WORKERS"
        continue
    fi

    # Topology change detection
    NEW_WORKERS=$(discover_workers)

    if [ "$NEW_WORKERS" != "$CURRENT_WORKERS" ]; then
        log "Worker topology changed!"
        log "  Previous: ${CURRENT_WORKERS:-none}"
        log "  Current:  ${NEW_WORKERS:-none}"

        stop_server
        CURRENT_WORKERS="$NEW_WORKERS"
        start_server "$CURRENT_WORKERS"
    fi
done
