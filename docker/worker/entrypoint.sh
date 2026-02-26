#!/bin/sh
set -e

ARGS="-H ${ROOKERY_HOST} -p ${ROOKERY_PORT}"

if [ "${ROOKERY_MEM}" != "0" ]; then
    ARGS="${ARGS} -m ${ROOKERY_MEM}"
fi

if [ "${ROOKERY_THREADS}" != "0" ]; then
    ARGS="${ARGS} -t ${ROOKERY_THREADS}"
fi

if [ "${ROOKERY_CACHE}" = "true" ]; then
    ARGS="${ARGS} -c"
fi

echo "[rookery-worker] Starting rpc-server"
echo "[rookery-worker] Listening: ${ROOKERY_HOST}:${ROOKERY_PORT}"
echo "[rookery-worker] Memory limit: ${ROOKERY_MEM:-auto} MB"
echo "[rookery-worker] Threads: ${ROOKERY_THREADS:-auto}"
echo "[rookery-worker] Cache: ${ROOKERY_CACHE}"

exec rpc-server ${ARGS}
