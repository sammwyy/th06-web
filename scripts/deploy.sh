#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${OUT_DIR:-build/web}"
config="${CONFIG:-Release}"
remote="${DEPLOY_REMOTE:-origin}"
branch="${DEPLOY_BRANCH:-gh-pages}"
worktree="${DEPLOY_WORKTREE:-$repo_root/build/gh-pages-worktree}"
message="${DEPLOY_MESSAGE:-Deploy browser build}"
skip_build=0
keep_worktree="${KEEP_DEPLOY_WORKTREE:-0}"

usage() {
  cat <<EOF
Usage: scripts/deploy.sh [--skip-build]
Builds and pushes build/web to gh-pages.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      skip_build=1
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

if [[ "$skip_build" == "0" ]]; then
  if [[ -n "${DEPLOY_BUILD_CMD:-}" ]]; then
    $DEPLOY_BUILD_CMD "$out_dir" "$config"
  elif command -v em++ >/dev/null 2>&1; then
    bash scripts/build.sh "$out_dir" "$config"
  else
    bash scripts/build-docker.sh "$out_dir" "$config"
  fi
fi

for artifact in index.html index.js index.wasm logo.png; do
  if [[ ! -f "$out_dir/$artifact" ]]; then
    echo "Missing deploy artifact: $out_dir/$artifact" >&2
    exit 1
  fi
done

if [[ -e "$worktree" ]]; then
  echo "Deploy worktree already exists: $worktree" >&2
  echo "Remove it or change DEPLOY_WORKTREE." >&2
  exit 1
fi

cleanup() {
  if [[ "$keep_worktree" != "1" && -d "$worktree" ]]; then
    git -C "$repo_root" worktree remove --force "$worktree" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null 2>&1; then
  git fetch "$remote" "$branch"
  git worktree add -B "$branch" "$worktree" FETCH_HEAD
elif git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add -B "$branch" "$worktree" "$branch"
else
  git worktree add --detach "$worktree" HEAD
  git -C "$worktree" switch --orphan "$branch"
fi

find "$worktree" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp "$out_dir/index.html" "$worktree/index.html"
cp "$out_dir/index.js" "$worktree/index.js"
cp "$out_dir/index.wasm" "$worktree/index.wasm"
cp "$out_dir/logo.png" "$worktree/logo.png"
touch "$worktree/.nojekyll"

git -C "$worktree" add -A

if git -C "$worktree" diff --cached --quiet; then
  echo "No changes to deploy."
  exit 0
fi

git -C "$worktree" commit -m "$message"
git -C "$worktree" push "$remote" "$branch"

echo "Deployed $out_dir to $remote/$branch"
