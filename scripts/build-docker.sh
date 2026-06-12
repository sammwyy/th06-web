#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${1:-${OUT_DIR:-build/web}}"
config="${2:-${CONFIG:-Release}}"
image="${EMSDK_DOCKER_IMAGE:-emscripten/emsdk:latest}"

docker run --rm \
  -v "$repo_root:/src" \
  -w /src \
  "$image" \
  bash scripts/build.sh "$out_dir" "$config"
