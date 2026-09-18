#!/usr/bin/env python3
"""
Stage new vg release notes for card drafting.

Fetches releases from the vgteam/vg GitHub repo and, for any release that
hasn't been turned into cards yet, writes a draft markdown file under
content/releases/. Draft files are NOT valid card YAML - they're raw
material for Aider (or a human) to turn into content/releases/<tag>.yaml
following content/schemas/card.schema.json.

A release is considered "done" once content/releases/<tag>.yaml exists;
re-running this script only stages releases that are missing both a
<tag>.yaml and a <tag>.draft.md.
"""

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = "vgteam/vg"
API_URL = f"https://api.github.com/repos/{REPO}/releases?per_page=20"

PROJECT_DIR = Path(__file__).resolve().parent.parent
RELEASES_DIR = PROJECT_DIR / "content" / "releases"


def safe_tag(tag: str) -> str:
    """Filesystem-safe version of a release tag."""
    return re.sub(r"[^A-Za-z0-9._-]", "_", tag)


def fetch_releases() -> list[dict]:
    req = urllib.request.Request(API_URL, headers={"Accept": "application/vnd.github+json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code == 403:
            print("GitHub API rate limit hit (unauthenticated requests are capped at 60/hr). "
                  "Try again later.", file=sys.stderr)
        else:
            print(f"GitHub API request failed: {e}", file=sys.stderr)
        return []
    except urllib.error.URLError as e:
        print(f"Could not reach GitHub API: {e}", file=sys.stderr)
        return []


def main():
    RELEASES_DIR.mkdir(parents=True, exist_ok=True)

    releases = fetch_releases()
    if not releases:
        print("No releases fetched.")
        return

    staged = 0
    for rel in releases:
        if rel.get("draft") or rel.get("prerelease"):
            continue

        tag = rel["tag_name"]
        stem = safe_tag(tag)
        card_file = RELEASES_DIR / f"{stem}.yaml"
        draft_file = RELEASES_DIR / f"{stem}.draft.md"

        if card_file.exists() or draft_file.exists():
            continue

        body = rel.get("body") or "(no release notes body)"
        draft_file.write_text(
            f"# vg {tag} release notes (staged for card drafting)\n\n"
            f"Published: {rel.get('published_at', 'unknown')}\n"
            f"URL: {rel.get('html_url', '')}\n\n"
            "---\n\n"
            f"{body}\n\n"
            "---\n\n"
            "## Next step\n\n"
            f"Turn the notable changes above into cards in `content/releases/{stem}.yaml`,\n"
            "following `content/schemas/card.schema.json`. Suggested frontmatter:\n\n"
            "```yaml\n"
            f"deck: vg-jargon::releases::{tag}\n"
            f"description: Notable changes in vg {tag}\n"
            "source_repo: vg\n\n"
            "cards:\n"
            "  - id: rel-001\n"
            "    type: basic\n"
            "    front: ...\n"
            "    back: ...\n"
            f"    tags: [release, {tag}]\n"
            "    difficulty: intermediate\n"
            "```\n\n"
            f"Once `{stem}.yaml` exists, delete this draft file.\n"
        )
        print(f"Staged {draft_file.relative_to(PROJECT_DIR)}")
        staged += 1

    if staged == 0:
        print("No new releases to stage - up to date.")
    else:
        print(f"\n{staged} release(s) staged in content/releases/.")
        print("Next: draft cards for each *.draft.md into a matching *.yaml, then delete the draft.")


if __name__ == "__main__":
    main()
