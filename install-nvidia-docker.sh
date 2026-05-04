#!/usr/bin/env bash
# Install + register nvidia-container-toolkit so Docker can pass a GPU
# into containers (needed for `docker compose --profile llm up`).
#
# Run with sudo: `sudo ./install-nvidia-docker.sh`
set -euo pipefail

KEYRING=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
LIST=/etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "==> Adding NVIDIA container toolkit repo"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor -o "$KEYRING"

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed "s#deb https://#deb [signed-by=$KEYRING] https://#g" \
  | tee "$LIST" > /dev/null

echo "==> Installing nvidia-container-toolkit"
apt-get update
apt-get install -y nvidia-container-toolkit

echo "==> Registering runtime with Docker"
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "==> Verifying GPU is visible inside a container"
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi

echo "==> Done. You can now: docker compose --profile llm up -d"
