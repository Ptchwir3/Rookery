# ============================================================================
# Rookery Worker - llama.cpp RPC server for distributed inference
# ============================================================================
# The worker runs rpc-server and exposes compute resources to the leader.
# It does NOT need access to the model file — the leader sends tensor
# data over the network. Workers just provide CPU/memory for computation.
#
# Build (multi-arch):
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     -t ptchwir3/rookery-worker:latest -f worker.Dockerfile --push .
#
# Run (standalone test):
#   docker run -it --rm -p 50052:50052 \
#     ptchwir3/rookery-worker:latest
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
# Bind host
ENV ROOKERY_HOST="0.0.0.0"
# RPC listen port
ENV ROOKERY_PORT="50052"
# Backend memory limit in MB (0 = auto/all available)
ENV ROOKERY_MEM="0"
# Number of CPU threads (0 = auto)
ENV ROOKERY_THREADS="0"
# Enable local tensor cache
ENV ROOKERY_CACHE="false"

EXPOSE 50052

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ss -tlnp | grep -q ":${ROOKERY_PORT}" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
