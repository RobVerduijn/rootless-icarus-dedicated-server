#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="registry.tjako.thuis:9999/library/icarus-dedicated-server"
IMAGE_TAG="1.22"

# Check for container engines in order: buildah, podman, docker
if command -v buildah &> /dev/null; then
    ENGINE="buildah"
elif command -v podman &> /dev/null; then
    ENGINE="podman"
elif command -v docker &> /dev/null; then
    ENGINE="docker"
else
    echo "Error: None of buildah, podman, or docker is installed." >&2
    exit 1
fi

echo "Using container engine: ${ENGINE}"

if [ "${ENGINE}" = "buildah" ]; then
    buildah bud \
      --tag "${IMAGE_NAME}:${IMAGE_TAG}" .
else
    "${ENGINE}" build \
      --tag "${IMAGE_NAME}:${IMAGE_TAG}" .
fi