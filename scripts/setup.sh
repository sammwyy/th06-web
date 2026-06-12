#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${EMSDK_DOCKER_IMAGE:-emscripten/emsdk:latest}"
pull_image=1

usage() {
  cat <<EOF
Usage: scripts/setup.sh [--no-pull]
Checks the few things we need.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-pull)
      pull_image=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$repo_root"

if ! command -v git >/dev/null 2>&1; then
  echo "Missing required command: git" >&2
  exit 1
fi

if [[ ! -f NotoSans-Regular.ttf ]]; then
  echo "Missing NotoSans-Regular.ttf at repo root." >&2
  exit 1
fi

if [[ ! -f web/logo.png ]]; then
  echo "Missing web/logo.png." >&2
  exit 1
fi

if command -v em++ >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Missing python3 for local em++ builds." >&2
    exit 1
  fi

  echo "Found native Emscripten: $(command -v em++)"
  echo "Setup OK. Build with: scripts/build.sh"
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "em++ was not found and docker is not available." >&2
  echo "Install Emscripten or use Docker." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but the daemon is not reachable." >&2
  exit 1
fi

if [[ "$pull_image" == "1" ]]; then
  echo "Pulling $image..."
  docker pull "$image"
fi

echo "Setup OK. Build with: scripts/build-docker.sh"
