# Rookery — Roadmap & TODO

## Phase 1: User Experience (This Week)

- [ ] **CLI wrapper (`rookery` command)**
  - [ ] `rookery install` — wraps `helm install` with sensible defaults
  - [ ] `rookery uninstall` — clean teardown
  - [ ] `rookery status` — shows pod health, node count, model info, API endpoint
  - [ ] `rookery logs` — follows leader logs
  - [ ] `rookery model set <url>` — switches model via `helm upgrade`
  - [ ] `rookery model list` — shows available recommended models for cluster size
  - [ ] `rookery chat` — opens interactive terminal chat session against the API
  - [ ] `rookery recommend` — checks total cluster RAM, suggests best model+quantization
  - [ ] Tab completion for bash/zsh
  - [ ] Install via `curl | bash` one-liner

- [ ] **CI/CD pipeline (GitHub Actions)**
  - [ ] Multi-arch Docker build on tag push (linux/amd64, linux/arm64)
  - [ ] Use GitHub's native ARM runners (no QEMU emulation)
  - [ ] Auto-push to Docker Hub on release
  - [ ] Helm chart linting on PR
  - [ ] Version tagging strategy (semver for chart, llama.cpp commit hash for images)

## Phase 2: Discovery & Growth

- [ ] **Demo content**
  - [ ] Asciicast/GIF in README showing full deploy flow (clone → install → chat)
  - [ ] Architecture diagram (proper SVG, not ASCII)
  - [ ] Screenshot of Open WebUI connected to Rookery

- [ ] **Launch posts**
  - [ ] Blog post: "Building a Raspberry Pi LLM Cluster with Rookery"
  - [ ] r/selfhosted
  - [ ] r/homelab
  - [ ] r/LocalLLaMA
  - [ ] r/kubernetes
  - [ ] Hacker News (Show HN)
  - [ ] HuggingFace community post

- [ ] **Project polish**
  - [ ] Logo/icon for the project
  - [ ] CONTRIBUTING.md
  - [ ] LICENSE file (MIT)
  - [ ] GitHub issue templates (bug report, feature request)
  - [ ] GitHub Discussions enabled

## Phase 3: Technical Improvements

- [ ] **Optimized ARM image tags**
  - [ ] `latest` — baseline armv8-a+crc+simd (Pi 4, all ARM64)
  - [ ] `latest-dotprod` — armv8.2+dotprod (Pi 5, Graviton2+)
  - [ ] `latest-i8mm` — armv8.6+i8mm (Graviton3+)
  - [ ] Document which tag to use for which hardware

- [ ] **Prometheus metrics & Grafana dashboard**
  - [ ] ServiceMonitor for llama-server `/metrics` endpoint
  - [ ] Grafana dashboard JSON (tokens/sec, active workers, memory per node, queue depth)
  - [ ] Optional Helm subchart or values toggle for monitoring stack
  - [ ] Document metrics endpoint in README

- [ ] **Worker health monitoring**
  - [ ] Sidecar container on leader that monitors worker DNS
  - [ ] Automatic leader restart when worker set changes (node added/removed)
  - [ ] Graceful handling of worker failure mid-inference
  - [ ] Leader readiness gate: don't mark ready until workers are confirmed

- [ ] **Automatic model selection**
  - [ ] `rookery recommend` queries cluster for total allocatable RAM
  - [ ] Curated model database: name, URL, size, min RAM, quality rating
  - [ ] Suggests best model+quantization for available resources
  - [ ] Optional: auto-download recommended model on install

## Phase 4: Advanced Features

- [ ] **GPU support**
  - [ ] CUDA worker Dockerfile (`rookery-worker:cuda`)
  - [ ] ROCm worker Dockerfile (`rookery-worker:rocm`)
  - [ ] `leader.nGpuLayers` tested and documented
  - [ ] Mixed CPU/GPU cluster guide (GPU box + Pis)
  - [ ] NVIDIA device plugin integration in Helm chart

- [ ] **Model preloading / tensor caching**
  - [ ] Workers retain frequently-used layers locally (`worker.cache=true`)
  - [ ] Measure network traffic reduction with caching enabled
  - [ ] Document cache warmup behavior and memory tradeoffs

- [ ] **Multi-model support**
  - [ ] Run multiple models simultaneously on the same cluster
  - [ ] API routing: `/v1/chat/completions` with `model` field selects backend
  - [ ] Hot-swap models without restarting the cluster

- [ ] **Speculative decoding out of the box**
  - [ ] Bundle a small draft model alongside the main model
  - [ ] Helm values for draft model URL and configuration
  - [ ] Document performance improvement expectations

## Phase 5: Management UI

- [ ] **Web-based cluster dashboard**
  - [ ] Node health overview (CPU, RAM, architecture per node)
  - [ ] Real-time inference metrics (tokens/sec, latency, queue)
  - [ ] Model management (switch models, view loaded model info)
  - [ ] One-click model switching from curated list
  - [ ] Worker status with per-node memory contribution visualization
  - [ ] Log viewer
  - [ ] Mobile-responsive design

## Bugs & Known Issues

- [ ] `warint` node consistently evicts worker pods (resource pressure)
- [ ] `g3server` shows NotReady — investigate and fix or exclude from DaemonSet
- [ ] rpc-server doesn't handle SIGINT cleanly (container stop requires `docker kill`)
- [ ] Leader doesn't re-discover workers if a new node joins after startup
- [ ] Model download has no progress indication in `kubectl get pods` (stuck on Init:0/2)

## Infrastructure & Ops

- [ ] Revoke exposed Docker Hub PAT and rotate credentials
- [ ] Set up local container registry (optional, avoids Docker Hub rate limits)
- [ ] Document K3s-specific setup notes (most Pi clusters use K3s)
- [ ] Test on MicroK8s and vanilla K8s
- [ ] Automated end-to-end test: deploy → curl → verify response → teardown
