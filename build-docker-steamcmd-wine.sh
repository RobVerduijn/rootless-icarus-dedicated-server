#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="registry.example.com:9999/library/icarus-dedicated-server"
IMAGE_TAG="1.22"

# Determine the container engine to use (prefer podman for rootless, fallback to docker)
if command -v podman &> /dev/null; then
    ENGINE="podman"
elif command -v docker &> /dev/null; then
    ENGINE="docker"
else
    echo "Error: Neither podman nor docker is installed." >&2
    exit 1
fi

echo "Using container engine: ${ENGINE}"

"${ENGINE}" build --tag "${IMAGE_NAME}:${IMAGE_TAG}" .