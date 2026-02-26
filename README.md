<p align="center">
  <h1 align="center">🐦 Rookery</h1>
  <p align="center">
    <strong>Turn any Kubernetes cluster into a private LLM endpoint.</strong><br>
    One Helm command. Commodity hardware. OpenAI-compatible API.
  </p>
  <p align="center">
    <a href="#quickstart">Quickstart</a> •
    <a href="#how-it-works">How It Works</a> •
    <a href="#models">Models</a> •
    <a href="#configuration">Configuration</a> •
    <a href="#performance-tuning">Performance Tuning</a> •
    <a href="#troubleshooting">Troubleshooting</a>
  </p>
</p>

---

Rookery deploys distributed LLM inference across heterogeneous Kubernetes clusters using [llama.cpp](https://github.com/ggml-org/llama.cpp) RPC. It runs on Raspberry Pis, old servers, mixed architectures — whatever you have. Workers pool their memory so you can run models larger than any single machine. The API is OpenAI-compatible, so it works with any client: [Open WebUI](https://github.com/open-webui/open-webui), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Continue](https://continue.dev/), [Cursor](https://cursor.sh/), [LangChain](https://www.langchain.com/), or your own apps.

**No expensive GPUs. No cloud dependencies. No data leaving your network.**

## Why Rookery?

Distributed LLM inference on commodity hardware isn't new — people have been dreaming about running large models on Pi clusters since 2023. Projects like [distributed-llama](https://github.com/b4rtaz/distributed-llama), [exo](https://github.com/exo-explore/exo), and [llm-d](https://github.com/llm-d/llm-d) all tackle parts of this problem. But none of them offer a **Kubernetes-native, Helm-deployable, multi-arch, one-command experience** for heterogeneous commodity hardware.

Rookery fills that gap:

- **One command deploy** — `helm install rookery ./helm/rookery` and you have a working LLM endpoint
- **Multi-architecture** — ARM64 (Raspberry Pi) and AMD64 (x86 servers) run side by side
- **Automatic worker discovery** — DaemonSet deploys workers on every node, leader finds them via DNS
- **Automatic model download** — specify a HuggingFace URL, the init container handles the rest
- **Memory-proportional distribution** — llama.cpp automatically gives each node layers proportional to its available RAM
- **OpenAI-compatible API** — drop-in replacement for any tool expecting `/v1/chat/completions`
- **Optional chat UI** — enable Open WebUI with `--set webui.enabled=true`
- **Private and air-gappable** — everything runs on your network, no external API calls

## Quickstart

### Prerequisites

- A Kubernetes cluster (K3s, K8s, MicroK8s — anything works)
- [Helm 3](https://helm.sh/docs/intro/install/) installed
- At least one node with 4GB+ free RAM
- Nodes can reach each other over the network

### Deploy

```bash
git clone https://github.com/Ptchwir3/Rookery.git
cd Rookery
helm install rookery ./helm/rookery
```

That's it. Rookery will:

1. Deploy a worker (`rpc-server`) on every node in your cluster
2. Download TinyLlama 1.1B (~637MB) to the leader node
3. Wait for workers to come online
4. Start the leader (`llama-server`) with automatic worker discovery
5. Expose an OpenAI-compatible API on port `30080`

### Test it

```bash
curl http://<any-node-ip>:30080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'
```

### Deploy with Chat UI

```bash
helm install rookery ./helm/rookery --set webui.enabled=true
```

Open WebUI will be available at `http://<any-node-ip>:30300`.

## How It Works

Rookery has three components:

```
┌─────────────────────────────────────────────────────┐
│                   Your Cluster                      │
│                                                     │
│  ┌──────────────┐    ┌──────────┐   ┌──────────┐    │
│  │    Leader     │◄──►│ Worker 1 │  │ Worker 2 │    │
│  │ (llama-server)│◄──►│(rpc-srv) │  │(rpc-srv) │    │
│  │              │◄──►│  4GB Pi  │   │  4GB Pi  │    │
│  │  API :8080   │    │  :50052  │   │  :50052  │    │
│  │  Model file  │    └──────────┘   └──────────┘    │
│  └──────┬───────┘                                   │
│         │            ┌──────────┐   ┌──────────┐    │
│         │            │ Worker 3 │   │ Worker N │    │
│         └───────────►│(rpc-srv) │   │(rpc-srv) │    │
│                      │  8GB Pi5 │   │ 16GB x86 │    │
│                      │  :50052  │   │  :50052  │    │
│                      └──────────┘   └──────────┘    │
└─────────────────────────────────────────────────────┘
         │
         ▼
  curl /v1/chat/completions
```

### Leader

A single pod running `llama-server` from llama.cpp. It:

- Holds the model file (GGUF format)
- Discovers workers via Kubernetes DNS (headless Service)
- Distributes model layers to workers proportional to their available memory
- Serves the OpenAI-compatible HTTP API
- Handles prompt processing, token sampling, and response generation

### Workers

A DaemonSet that runs `rpc-server` on every node. Each worker:

- Advertises its available memory to the leader
- Receives tensor data and executes compute operations locally
- Returns results to the leader over TCP (port 50052)
- Requires **no model file access** — the leader sends everything over the network

### Model Downloader

An init container on the leader pod that:

- Downloads the GGUF model from HuggingFace (or any URL) on first deploy
- Stores it on the leader node via HostPath (`/var/lib/rookery/models`)
- Skips download if the model already exists (fast restarts)
- Uses atomic write (download to `.tmp`, then rename) to prevent corruption

## Models

### Choosing a Model

The rule of thumb for GGUF models at Q4 quantization: **~0.5GB per billion parameters**.

| Model | Parameters | Size (Q4) | Min Cluster RAM | Quality | Speed* |
|-------|-----------|-----------|----------------|---------|--------|
| TinyLlama 1.1B | 1.1B | ~637MB | 2GB | Basic — good for testing | Fast |
| Phi-3 Mini | 3.8B | ~2.2GB | 4GB | Solid for code and reasoning | Fast |
| Llama 3.1 8B | 8B | ~4.5GB | 8GB | Excellent general purpose | Good |
| Mistral 7B v0.3 | 7B | ~4GB | 8GB | Strong instruction following | Good |
| Qwen 2.5 7B | 7B | ~4.5GB | 8GB | Multilingual, strong coding | Good |
| Deepseek-R1-Distill 14B | 14B | ~8GB | 12GB | Excellent reasoning | Moderate |
| Qwen 2.5 32B | 32B | ~18GB | 24GB | Near-frontier quality | Slower |
| CodeLlama 34B | 34B | ~20GB | 24GB | Specialized code generation | Slower |
| Llama 3.1 70B | 70B | ~40GB | 48GB | Production-quality | Slow |
| Deepseek V3 671B (MoE) | 671B | ~230GB | 256GB+ | Frontier-class | Very slow |

*Speed is relative and depends on cluster size, network, and hardware. See [Performance Tuning](#performance-tuning).

### Deploying a Different Model

Override the model URL at install time:

```bash
# Llama 3.1 8B — great balance of quality and speed
helm install rookery ./helm/rookery \
  --set model.url="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"

# Qwen 2.5 7B — strong multilingual and coding
helm install rookery ./helm/rookery \
  --set model.url="https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf"

# Llama 3.1 70B — production quality, needs ~48GB cluster RAM
helm install rookery ./helm/rookery \
  --set model.url="https://huggingface.co/bartowski/Meta-Llama-3.1-70B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf"
```

### Using a Local Model

If you already have a GGUF file on the leader node:

```bash
# Copy model to the Rookery model directory
sudo mkdir -p /var/lib/rookery/models
sudo cp /path/to/your-model.gguf /var/lib/rookery/models/

# Deploy with local filename (no download)
helm install rookery ./helm/rookery \
  --set model.url="" \
  --set model.filename="your-model.gguf"
```

### Finding Models

GGUF models are available on HuggingFace. Look for files ending in `.gguf` with `Q4_K_M` quantization for the best balance of quality and size:

- [TheBloke's GGUF collection](https://huggingface.co/TheBloke) — large curated library
- [bartowski's GGUF models](https://huggingface.co/bartowski) — up-to-date quantizations
- Search HuggingFace for `[model name] GGUF Q4_K_M`

### Quantization Guide

| Quantization | Bits/Weight | Quality | Size vs FP16 | When to Use |
|-------------|-------------|---------|---------------|-------------|
| Q2_K | ~2.5 | Poor | ~16% | Extreme memory constraints only |
| Q3_K_M | ~3.5 | Fair | ~22% | When you're a few GB short |
| **Q4_K_M** | **~4.5** | **Good** | **~28%** | **Recommended default** |
| Q5_K_M | ~5.5 | Very good | ~34% | When you have headroom |
| Q6_K | ~6.5 | Excellent | ~40% | Near-lossless, if RAM allows |
| Q8_0 | ~8.0 | Near-perfect | ~50% | When quality is critical |
| FP16 | 16.0 | Perfect | 100% | Reference only, impractical for most |

**Q4_K_M** is the sweet spot for distributed inference — it minimizes data transferred over the network while maintaining good output quality.

## Configuration

### values.yaml Reference


All configuration is done through Helm values. Here's the complete reference:

#### Model Settings

```yaml
model:
  url: "https://huggingface.co/..."    # HuggingFace URL to GGUF file
  filename: ""                          # Override filename (auto-derived from URL)
  hostPath: /var/lib/rookery/models     # Where models are stored on the leader node
  storageSize: 100Gi                    # PV size allocation
```

#### Leader Settings

```yaml
leader:
  image:
    repository: ptchwir3/rookery-leader
    tag: latest
  nodeSelector: {}           # Pin leader to a specific node
  resources: {}              # CPU/memory requests and limits
  ctxSize: 2048              # Context window size (tokens)
  nGpuLayers: 0              # GPU layers (0 = CPU only)
  parallel: 1                # Concurrent request slots
  extraArgs: ""              # Additional llama-server flags
  service:
    type: NodePort
    port: 8080               # Internal service port
    nodePort: 30080           # External access port
```

#### Worker Settings

```yaml
worker:
  image:
    repository: ptchwir3/rookery-worker
    tag: latest
  resources: {}              # CPU/memory requests and limits
  port: 50052                # RPC listen port
  memory: 0                  # Memory limit in MB (0 = all available)
  threads: 0                 # CPU threads (0 = auto-detect)
  cache: false               # Local tensor cache
  nodeSelector: {}           # Restrict which nodes run workers
  tolerations: []            # Tolerate node taints (e.g., ARM nodes)
  excludeLeaderNode: false   # Skip the leader's node
```

#### WebUI Settings

```yaml
webui:
  enabled: false             # Set to true to deploy Open WebUI
  image:
    repository: ghcr.io/open-webui/open-webui
    tag: latest
  service:
    type: NodePort
    port: 3000
    nodePort: 30300
```

### Common Deployment Patterns

#### Pin leader to your most powerful node

```bash
helm install rookery ./helm/rookery \
  --set leader.nodeSelector."kubernetes\.io/hostname"=my-big-server
```

#### Large context window for long documents

```bash
helm install rookery ./helm/rookery \
  --set leader.ctxSize=8192
```

#### Restrict workers to specific nodes

```bash
helm install rookery ./helm/rookery \
  --set worker.nodeSelector."node-role\.kubernetes\.io/worker"=""
```

#### Full production deployment

```bash
helm install rookery ./helm/rookery \
  --set model.url="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" \
  --set leader.nodeSelector."kubernetes\.io/hostname"=my-big-server \
  --set leader.ctxSize=4096 \
  --set leader.service.nodePort=30880 \
  --set webui.enabled=true
```

## API Usage

Rookery exposes a standard OpenAI-compatible API. Any tool or library that works with the OpenAI API works with Rookery — just point it at your cluster's address.

### Chat Completions

```bash
curl http://<node-ip>:30080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Explain Kubernetes in one paragraph."}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### Streaming

```bash
curl http://<node-ip>:30080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Write a haiku about servers."}],
    "stream": true
  }'
```

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<node-ip>:30080/v1",
    api_key="rookery"  # any string works, no auth required
)

response = client.chat.completions.create(
    model="any",  # model name is ignored, uses whatever is loaded
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

### Use with Claude Code

```bash
# Configure Claude Code to use your Rookery endpoint
export OPENAI_BASE_URL="http://<node-ip>:30080/v1"
export OPENAI_API_KEY="rookery"
```

### Use with Continue (VS Code)

Add to your Continue config (`~/.continue/config.json`):

```json
{
  "models": [{
    "title": "Rookery",
    "provider": "openai",
    "model": "rookery",
    "apiBase": "http://<node-ip>:30080/v1",
    "apiKey": "rookery"
  }]
}
```

### Health Check

```bash
curl http://<node-ip>:30080/health
```

### List Loaded Models

```bash
curl http://<node-ip>:30080/v1/models
```

## Performance Tuning

### Network Optimization

Network is the primary bottleneck in distributed inference. Each layer split across a node boundary requires tensor data to travel over the network.

| Improvement | Impact | Cost |
|------------|--------|------|
| Jumbo frames (MTU 9000) | ~10-15% throughput increase | Free (switch config) |
| Pi 5 over Pi 4 | True Gigabit (vs ~400Mbps USB-limited) | ~$80/node |
| 2.5GbE adapter on Pi 5 | 2.5x bandwidth via PCIe | ~$15/adapter + switch |
| 10GbE on x86 nodes | Eliminates network bottleneck | ~$30/adapter + switch |
| Fewer, larger nodes | Fewer network hops | Varies |

**Most impactful change**: Reduce the number of nodes. Two 32GB machines will always outperform eight 4GB Pis because there are fewer network hops. Used Dell Optiplex mini PCs with 32-64GB DDR4 go for $100-200 on eBay.

### KV Cache Quantization

Reduces memory used by the key-value cache, leaving more room for model layers:

```bash
helm install rookery ./helm/rookery \
  --set leader.extraArgs="--cache-type-k q4_0 --cache-type-v q4_0"
```

This cuts KV cache memory roughly in half with minimal quality impact.

### Speculative Decoding

Use a small model to draft tokens, then verify in batches against the large model. This can 2-3x throughput because verification is parallelizable:

```bash
# Download a small draft model alongside the main model
helm install rookery ./helm/rookery \
  --set leader.extraArgs="--model-draft /models/tinyllama.gguf"
```

You'll need both models in the model directory on the leader node.

### Worker Memory Limits

If workers are running other workloads, limit how much RAM the RPC server uses:

```bash
helm install rookery ./helm/rookery \
  --set worker.memory=2048  # Limit each worker to 2GB
```

### Parallel Request Slots

For serving multiple users, increase parallel slots (trades per-request speed for throughput):

```bash
helm install rookery ./helm/rookery \
  --set leader.parallel=4
```

### Thread Tuning

By default, workers auto-detect CPU thread count. Override if needed:

```bash
helm install rookery ./helm/rookery \
  --set worker.threads=4
```

On Raspberry Pi 4 (4 cores), the default is usually correct. On larger servers, you may want to leave some cores free for the OS.

## Example Cluster Configurations

### Minimal — One Node

A single machine with 8GB+ RAM. Workers and leader on the same node. Good for testing.

```
1x Any machine (8GB RAM)
├── Leader + Worker
├── Model: Llama 3.1 8B Q4 (~4.5GB)
└── Performance: ~15-25 tok/s
```

### Budget — Pi Cluster

The classic Raspberry Pi setup. Cheap, fun, educational.

```
6x Raspberry Pi 4 (4GB each) = 24GB
1x Raspberry Pi 5 (8GB)      =  8GB
2x AMD64 server (16GB each)  = 32GB
                        Total = 64GB

├── Model: Llama 3.1 70B Q4 (~40GB)
├── Leader: pinned to AMD64 server
├── Workers: all 9 nodes
└── Performance: ~1-3 tok/s
```

### Performance — Used Workstations

Best bang for buck. eBay workstations with maxed RAM.

```
3x Dell Optiplex (64GB DDR4 each) = 192GB

├── Model: Llama 3.1 70B Q8 (~70GB) or Deepseek 33B Q8
├── Leader: any node
├── Workers: all 3 nodes (only 2 network hops)
└── Performance: ~5-10 tok/s
```

### Enterprise — Mixed Fleet

Combine everything you have.

```
4x Raspberry Pi 5 (8GB each)     =  32GB
2x Old laptops (16GB each)       =  32GB
1x Workstation with GPU (64GB)   =  64GB
                           Total = 128GB

├── Model: Deepseek 671B MoE Q2 (~100GB)
├── Leader: pinned to workstation
├── GPU offload: --set leader.nGpuLayers=20
└── Performance: varies
```

## Upgrading

### Change Models

```bash
# Switch to a different model
helm upgrade rookery ./helm/rookery \
  --set model.url="https://huggingface.co/new-model.gguf"
```

The leader pod will restart, download the new model, and come back up.

### Update Rookery

```bash
git pull
helm upgrade rookery ./helm/rookery
```

### Rollback

```bash
helm rollback rookery 1  # Roll back to revision 1
```

## Troubleshooting

### Check Pod Status

```bash
# Overview of all Rookery pods
kubectl get pods -l app.kubernetes.io/part-of=rookery -o wide

# Watch pods come up in real-time
kubectl get pods -l app.kubernetes.io/part-of=rookery -w
```

### Workers Stuck on ImagePullBackOff

The worker image doesn't match the node's architecture. Ensure you're using multi-arch images:

```bash
# Check node architectures
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Rebuild multi-arch and push
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ptchwir3/rookery-worker:latest --push .
```

### Leader Stuck on Init:0/2

The model is downloading. Check progress:

```bash
kubectl logs <leader-pod> -c model-downloader -f
```

### Leader Stuck on Init:1/2

Waiting for workers. Check if any workers are ready:

```bash
kubectl get pods -l app.kubernetes.io/component=worker
```

If no workers are running, check their logs:

```bash
kubectl logs <worker-pod>
```

### Leader Starts but No Workers Found

DNS discovery failed. Verify the headless service resolves:

```bash
kubectl exec <leader-pod> -- getent hosts rookery-worker.default.svc.cluster.local
```

If it returns nothing, workers aren't ready yet or the service selector doesn't match.

### Out of Memory / OOM Killed

The model is too large for your cluster's available RAM. Options:

- Use a smaller model or more aggressive quantization (Q3_K_M or Q2_K)
- Add more nodes to the cluster
- Limit worker memory with `worker.memory` to leave room for the OS
- Reduce context size with `leader.ctxSize`

### Slow Inference

Distributed inference is inherently slower than single-node due to network overhead. To improve:

- Pin the leader to your fastest node with `leader.nodeSelector`
- Reduce the number of nodes (fewer, bigger machines = fewer network hops)
- Enable KV cache quantization: `--set leader.extraArgs="--cache-type-k q4_0 --cache-type-v q4_0"`
- Use jumbo frames on your network switch (MTU 9000)
- Keep `leader.parallel=1` for single-user scenarios

### Worker Evicted

The node ran out of resources. Either:

- Set resource limits: `--set worker.resources.limits.memory=2Gi`
- Exclude resource-constrained nodes via `worker.nodeSelector`

### View Leader Startup Logs

```bash
kubectl logs -l app.kubernetes.io/component=leader -f
```

Look for:
- `[rookery-leader] Found workers: ...` — confirms worker discovery
- `llama_model_load_from_file_impl: using device RPC0` — confirms RPC connection
- `main: server is listening on http://0.0.0.0:8080` — API is ready

### Complete Teardown

```bash
helm uninstall rookery

# Optionally remove downloaded models
sudo rm -rf /var/lib/rookery
```

## Architecture Decisions

**Why llama.cpp RPC instead of MPI?** RPC is simpler to deploy (TCP sockets vs MPI daemon), works across heterogeneous architectures without shared filesystems, and is actively maintained as part of llama.cpp. MPI requires all nodes to have the model file; RPC only needs it on the leader.

**Why DaemonSet for workers?** A DaemonSet automatically deploys one worker per node and handles node additions/removals. No manual configuration of IP addresses. Combined with a headless Service, the leader discovers all workers through DNS.

**Why HostPath instead of NFS/PVC?** Only the leader needs the model file — workers receive tensor data over RPC. This eliminates the need for shared storage entirely. HostPath is the simplest volume type and works on any cluster.

**Why busybox for init containers?** Minimal image size (~5MB), available for all architectures, has `wget` for downloading and `nslookup` for DNS discovery. No need for a full OS image just to download a file.

**Why not GPU support by default?** Rookery targets commodity hardware where GPUs are the exception, not the rule. GPU support works if you have it (`leader.nGpuLayers > 0`), but the default is CPU-only because that's what most Raspberry Pis and old servers have.

## Security Considerations

⚠️ **llama.cpp RPC is not encrypted.** The RPC protocol between leader and workers transmits tensor data in plaintext over TCP. This is fine on a private cluster network but **never expose port 50052 to the internet**.

The OpenAI-compatible API has **no authentication by default**. If you expose it outside your cluster, consider:

- Using a Kubernetes NetworkPolicy to restrict access
- Putting it behind an ingress controller with authentication
- Using `ClusterIP` service type instead of `NodePort` and accessing via `kubectl port-forward`

## Contributing

Contributions are welcome. Areas where help is especially needed:

- **Benchmarks** — Performance data on different cluster configurations
- **GPU support** — CUDA/ROCm worker images for mixed CPU/GPU clusters
- **Monitoring** — Prometheus metrics and Grafana dashboards
- **Autoscaling** — Dynamic model loading based on available cluster resources
- **Documentation** — Guides for specific hardware setups

## License

MIT

## Acknowledgements

- [llama.cpp](https://github.com/ggml-org/llama.cpp) by Georgi Gerganov — the engine that makes all of this possible
- [rgerganov](https://github.com/rgerganov) — author of the llama.cpp RPC backend
- [Open WebUI](https://github.com/open-webui/open-webui) — the chat frontend
- Everyone building and sharing GGUF models on HuggingFace

