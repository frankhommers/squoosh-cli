#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/frankhommers/squoosh-cli:latest}"

docker run --rm \
  -v "$(pwd)":/work \
  -w /work \
  "$IMAGE_NAME" "$@"
