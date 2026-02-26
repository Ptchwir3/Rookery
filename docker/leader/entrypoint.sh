#!/bin/sh
set -e

ARGS="--model ${ROOKERY_MODEL} \
      --host ${ROOKERY_HOST} \
      --port ${ROOKERY_PORT} \
      --ctx-size ${ROOKERY_CTX_SIZE} \
      --n-gpu-layers ${ROOKERY_N_GPU_LAYERS} \
      --parallel ${ROOKERY_PARALLEL}"

if [ -n "${ROOKERY_RPC_SERVERS}" ]; then
    ARGS="${ARGS} --rpc ${ROOKERY_RPC_SERVERS}"
fi

if [ -n "${ROOKERY_EXTRA_ARGS}" ]; then
    ARGS="${ARGS} ${ROOKERY_EXTRA_ARGS}"
fi

echo "[rookery-leader] Starting llama-server"
echo "[rookery-leader] Model: ${ROOKERY_MODEL}"
echo "[rookery-leader] RPC workers: ${ROOKERY_RPC_SERVERS:-none (standalone)}"
echo "[rookery-leader] API: http://${ROOKERY_HOST}:${ROOKERY_PORT}"

exec llama-server ${ARGS}
