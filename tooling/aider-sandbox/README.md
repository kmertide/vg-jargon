# aider-sandbox

A locked-down container for running [Aider](https://aider.chat) against a local Ollama
model. Built for drafting vg-jargon cards, but generic enough to point at any project.

## What's sandboxed

- **Filesystem:** only the target project directory is mounted, and it's the only
  writable mount. An optional sibling `vgteam_repos/` (or `$REFS_DIR`) is mounted
  read-only at `/refs` for reference material Aider can't edit.
- **Privileges:** `--cap-drop=ALL --security-opt no-new-privileges`, non-root container
  user.
- **Resources:** capped at 12GB RAM / 6 CPUs.
- **Model:** runs against your host's Ollama over `host.docker.internal:11434` — nothing
  leaves your machine.

## Usage

```bash
docker build -t aider-sandbox .
./run.sh                          # operate on the parent repo (default)
./run.sh /path/to/other/project    # operate on a different directory
```

Env overrides: `AIDER_MODEL` (default `ollama_chat/qwen2.5-coder:32b`), `REFS_DIR`.

## Known gotchas (found while building this)

- **`git` must be installed in the image** — `python:3.12-slim` doesn't include it, and
  without it Aider silently reports "Git repo: none" and can't auto-commit.
- **`git config --global --add safe.directory /workspace`** is required — Docker Desktop
  bind mounts on macOS don't preserve host UID, so git's dubious-ownership check blocks
  commits inside the container otherwise.
- **`--no-check-update`** is required when running non-interactively (`--message` /
  `-m`) — without it, Aider's own update-check prompt can hang waiting on stdin that
  will never come.
- **Don't trust the model to run its own cleanup shell commands.** Aider only
  auto-executes commands the model puts in a proper fenced code block; a plain-text
  `rm somefile` in its reply is never actually run. Do file cleanup deterministically in
  your own scripts instead of asking the model to do it.
