# RADAR — Deployment

Docker Compose deployment for RADAR. Builds iamges
from source (you must clone them into the dir) and wires them up
with an optional bundled Ollama for the chat feature.

## Prerequisites

- **Docker** with Compose v2 (`docker compose ...`).
- **~6 GB free disk** if you enable the LLM profile (the default
  `qwen2.5:7b-instruct` model is ~4.7 GB).
- **NVIDIA GPU + drivers** if you want GPU-accelerated inference.
  Run `./install-nvidia-docker.sh` once on a fresh Ubuntu host to
  install the NVIDIA Container Toolkit. Without a GPU, remove the
  `deploy.resources.reservations.devices` block from the `ollama`
  service in `docker-compose.yml` — Ollama will fall back to CPU.

## Quickstart

```sh
git clone https://github.com/fairscape/radar_deployment.git
cd radar_deployment

# Clone backend + frontend as siblings (the compose build context
# points at ../radar-backend and ../radar-website — see note below).
git clone https://github.com/fairscape/radar_backend.git ../radar-backend
git clone https://github.com/fairscape/radar_frontend.git ../radar-website

cp .env.example .env

# Full demo with bundled Ollama (recommended).
# First run pulls model weights — takes 5–15 min on a typical
# connection. Weights persist in ./ollama so subsequent ups are fast.
docker compose --profile llm up -d

# Or, no chat (skips ollama + the model download):
# docker compose up -d
```

Then open **http://localhost:5173** and confirm the API:

```sh
curl http://localhost:8000/api/health
# {"status":"ok","version":"..."}
```

> **Note on layout.** `docker-compose.yml` currently expects sibling
> directories `../radar-backend` and `../radar-website` for its build
> contexts. If you'd rather pull pre-built images from a registry,
> swap each service's `build:` block for an `image: ghcr.io/...` line.

## Where state lives

Four bind-mounts under this directory, all created on first `up`:

| Path        | Contents                                          |
|-------------|---------------------------------------------------|
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

## Common tasks

**Rebuild after code changes:**

```sh
docker compose --profile llm up -d --build backend
docker compose --profile llm up -d --build frontend
```

**Logs:**

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

**Port conflicts:** edit the `ports:` mapping in `docker-compose.yml`
(e.g. `"5174:5173"`). If you change the frontend port, also update the
`VITE_API_BASE_URL` build arg and `RADAR_CORS_ORIGINS` in `.env`.

## Troubleshooting

- **Chat returns 503** — start with `--profile llm`, confirm the model
  pulled (`ollama list`), and verify `RADAR_OLLAMA_URL=http://ollama:11434`
  in `.env` (the in-compose hostname is `ollama`, not `localhost`).
- **Backend can't write to `./data`** — bind-mounted dirs inherit the
  container UID. If you're running rootless Docker or hit perms issues,
  `chown -R $(id -u):$(id -g) data vault chroma`.
