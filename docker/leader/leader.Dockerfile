# ============================================================================
# Rookery Leader - llama.cpp server with RPC distributed inference
# ============================================================================
# The leader runs llama-server and coordinates distributed inference across
# worker nodes running rpc-server. It loads the model, distributes layers
# to workers based on available memory, and exposes an OpenAI-compatible API.
#
# Build (multi-arch):
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     -t ptchwir3/rookery-leader:latest -f leader.Dockerfile --push .
#
# Run (standalone test):
#   docker run -it --rm -p 8080:8080 \
#     -v /path/to/models:/models \
#     -e ROOKERY_MODEL=/models/your-model.gguf \
#     ptchwir3/rookery-leader:latest
# ============================================================================

# ------------------------------
# Stage 1: Build llama.cpp
# ------------------------------
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG LLAMA_CPP_VERSION=master

RUN git clone --depth 1 --branch ${LLAMA_CPP_VERSION} \
    https://github.com/ggml-org/llama.cpp.git /src/llama.cpp

WORKDIR /src/llama.cpp

# Build with RPC support enabled
# GGML_RPC=ON enables the RPC backend for distributed inference
RUN cmake -B build \
    -DGGML_RPC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/rookery \
    -DGGML_CPU_ARM_ARCH=armv8-a+crc+simd \
    -DGGML_NATIVE=OFF \
    && cmake --build build --config Release -j$(nproc) \
    && cmake --install build

# ------------------------------
# Stage 2: Runtime
# ------------------------------
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy entire install prefix (binaries + shared libraries)
COPY --from=builder /opt/rookery /opt/rookery
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Make sure the dynamic linker can find our shared libs
ENV PATH="/opt/rookery/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/rookery/lib"

# Create non-root user
RUN useradd -m -u 2000 rookery
USER rookery
WORKDIR /home/rookery

# ---- Configuration via environment variables ----
# Model path (required)
ENV ROOKERY_MODEL=""
# RPC worker addresses (comma-separated host:port, legacy — prefer discovery)
ENV ROOKERY_RPC_SERVERS=""
# API listen host and port
ENV ROOKERY_HOST="0.0.0.0"
ENV ROOKERY_PORT="8080"
# Context size
ENV ROOKERY_CTX_SIZE="2048"
# Number of GPU layers (0 for CPU-only)
ENV ROOKERY_N_GPU_LAYERS="0"
# Number of parallel request slots
ENV ROOKERY_PARALLEL="1"
# Additional llama-server flags
ENV ROOKERY_EXTRA_ARGS=""
# Worker discovery (set by Helm, used by entrypoint)
ENV ROOKERY_WORKER_SVC=""
ENV ROOKERY_WORKER_PORT="50052"
ENV ROOKERY_DISCOVERY_INTERVAL="30"

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:${ROOKERY_PORT}/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
