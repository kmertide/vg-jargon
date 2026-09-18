#!/usr/bin/env bash
# Run Aider in a sandboxed container against a local Ollama model.
#
# Usage:
#   ./run.sh                          # operate on this repo (default)
#   ./run.sh /path/to/other/project    # operate on a different directory
#   ./run.sh . -m "some one-shot instruction"   # extra args pass through to aider
#
# Only the target project directory is visible/writable inside the
# container. Everything else on the host is inaccessible to Aider.
#
# Env overrides:
#   AIDER_MODEL   - defaults to ollama_chat/qwen2.5-coder:32b
#   REFS_DIR       - read-only reference dir mounted at /refs (defaults to a
#                     sibling ../vgteam_repos of the project dir, if present)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ $# -ge 1 ] && [ -d "$1" ]; then
  PROJECT_DIR="$(cd "$1" && pwd)"
  shift
else
  PROJECT_DIR="$REPO_ROOT"
fi

MODEL="${AIDER_MODEL:-ollama_chat/qwen2.5-coder:32b}"

REFS_DIR="${REFS_DIR:-$(dirname "$PROJECT_DIR")/vgteam_repos}"
EXTRA_MOUNT=()
if [ -d "$REFS_DIR" ]; then
  EXTRA_MOUNT=(-v "$REFS_DIR:/refs:ro")
  echo "Mounting $REFS_DIR read-only at /refs"
fi

if ! docker image inspect aider-sandbox >/dev/null 2>&1; then
  echo "Building aider-sandbox image..."
  docker build -t aider-sandbox "$SCRIPT_DIR"
fi

echo "Target project: $PROJECT_DIR"

docker run --rm -it \
  --name aider-test \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory=12g --cpus=6 \
  --add-host=host.docker.internal:host-gateway \
  -e OLLAMA_API_BASE=http://host.docker.internal:11434 \
  -e AIDER_ANALYTICS=false \
  -v "$PROJECT_DIR:/workspace" \
  "${EXTRA_MOUNT[@]}" \
  aider-sandbox \
  --model "$MODEL" \
  "$@"
