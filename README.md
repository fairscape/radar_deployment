# RADAR — Deployment

Docker Compose deployment for RADAR. Pulls pre-built images from
`ghcr.io/fairscape/` and wires them up with an optional bundled Ollama
for the chat feature.

## Prerequisites

- **Docker** with Compose v2 (`docker compose ...`).
- **~6 GB free disk** if you enable the LLM profile (the default
  `qwen2.5:7b-instruct` model is ~4.7 GB).
- **NVIDIA GPU + drivers** if you want GPU-accelerated inference with
  the `llm` profile. Run `./install-nvidia-docker.sh` once on a fresh
  Ubuntu host to install the NVIDIA Container Toolkit, then confirm
  Docker can see the GPU:

  ```sh
  docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
  ```

  If that prints an `nvidia-smi` table, you're good. Without a GPU,
  remove the `deploy.resources.reservations.devices` block from the
  `ollama` service in `docker-compose.yml` — Ollama will fall back to
  CPU (slow but works).

## Quickstart

Two options — pick one:

```sh
git clone https://github.com/fairscape/radar_deployment.git
cd radar_deployment

# Option A — full demo, with chat (needs GPU, see above).
# First run pulls Ollama model weights — 5–15 min, persists in ./ollama.
docker compose --profile llm up -d

# Option B — no chat, no Ollama.
docker compose up -d
```

Then open **http://localhost:5173** and confirm the API:

```sh
curl http://localhost:8000/api/health
# {"status":"ok","version":"..."}
```

## Where state lives

Four bind-mounts under this directory, all created on first `up`:

| Path        | Contents                                          |
| ----------- | ------------------------------------------------- |
| `./data/`   | `radar.db` SQLite + WAL/SHM sidecars.             |
| `./vault/`  | Per-user PDFs and `feedback.jsonl`.               |
| `./chroma/` | Per-user Chroma collections (vault chunk index).  |
| `./ollama/` | Ollama model weights (only with `--profile llm`). |

Override locations by setting `RADAR_HOST_{DATA,VAULT,CHROMA,OLLAMA}_DIR`
in `.env` (see `.env.example`).

To wipe state and start fresh:

```sh
docker compose --profile llm down
rm -rf data vault chroma          # ollama/ optional — saves a re-pull
docker compose --profile llm up -d
```

## Logs

```sh
docker compose logs -f backend
docker compose logs -f frontend
docker compose --profile llm logs -f ollama
```

**Verify the LLM model pulled:**

```sh
docker compose --profile llm logs ollama-init
# "Pull complete." means it's done.
docker compose --profile llm exec ollama ollama list
```

## Troubleshooting

- **Chat returns 503** — start with `--profile llm`, confirm the model
  pulled (`ollama list`), and verify `RADAR_OLLAMA_URL=http://ollama:11434`
  in `.env` (the in-compose hostname is `ollama`, not `localhost`).
- **Backend can't write to `./data`** — bind-mounted dirs inherit the
  container UID. If you're running rootless Docker or hit perms issues,
  `chown -R $(id -u):$(id -g) data vault chroma`.
- **Port conflicts** — edit the `ports:` mapping in `docker-compose.yml`
  (e.g. `"5174:5173"`). Frontend port changes also need the image
  rebuilt with a matching `VITE_API_BASE_URL` build arg.
