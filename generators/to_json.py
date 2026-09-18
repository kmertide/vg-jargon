#!/usr/bin/env python3
"""
Generate JSON flashcard database from YAML content files.
Output is consumed by the macOS widget.
"""

import json
import yaml
import re
from pathlib import Path
from datetime import datetime

CONTENT_DIR = Path(__file__).parent.parent / "content"
OUTPUT_FILE = Path(__file__).parent.parent / "widget" / "cards.json"


def load_yaml_cards(content_dir: Path) -> list[dict]:
    """Load all cards from YAML files in content directory."""
    cards = []

    for yaml_file in content_dir.rglob("*.yaml"):
        if yaml_file.parent.name == "schemas":
            continue

        with open(yaml_file) as f:
            data = yaml.safe_load(f)

        if not data or "cards" not in data:
            continue

        deck = data.get("deck", "vg-jargon")
        source_repo = data.get("source_repo", "")

        for card in data["cards"]:
            card["deck"] = deck
            if source_repo and "source" in card:
                card["source"] = f"{source_repo}/{card['source']}"
            cards.append(card)

    return cards


def process_cloze(text: str) -> list[dict]:
    """Expand cloze deletions into multiple cards."""
    cloze_pattern = r'\{\{c(\d+)::([^}]+)\}\}'
    matches = list(re.finditer(cloze_pattern, text))

    if not matches:
        return []

    cards = []
    cloze_nums = set(m.group(1) for m in matches)

    for num in sorted(cloze_nums):
        front = text
        back = text

        for match in matches:
            cloze_num = match.group(1)
            answer = match.group(2)

            if cloze_num == num:
                front = front.replace(match.group(0), "[...]")
                back = back.replace(match.group(0), f"**{answer}**")
            else:
                front = front.replace(match.group(0), answer)
                back = back.replace(match.group(0), answer)

        cards.append({"front": front.strip(), "back": back.strip()})

    return cards


def transform_card(card: dict) -> list[dict]:
    """Transform a YAML card into widget-ready format(s)."""
    base = {
        "id": card["id"],
        "deck": card.get("deck", "vg-jargon"),
        "tags": card.get("tags", []),
        "difficulty": card.get("difficulty", "intermediate"),
        "source": card.get("source", ""),
    }

    if card["type"] == "basic":
        return [{**base, "front": card["front"], "back": card["back"]}]

    elif card["type"] == "cloze":
        cloze_cards = process_cloze(card["text"])
        return [{
            **base,
            "id": f"{card['id']}-c{i+1}",
            "front": c["front"],
            "back": c["back"],
        } for i, c in enumerate(cloze_cards)]

    elif card["type"] == "reverse":
        return [
            {**base, "front": card["front"], "back": card["back"]},
            {**base, "id": f"{card['id']}-rev", "front": card["back"], "back": card["front"]},
        ]

    return []


def generate_json():
    """Generate the JSON database for the widget."""
    yaml_cards = load_yaml_cards(CONTENT_DIR)

    all_cards = []
    for card in yaml_cards:
        all_cards.extend(transform_card(card))

    output = {
        "version": "1.0.0",
        "generated": datetime.now().isoformat(),
        "card_count": len(all_cards),
        "decks": list(set(c["deck"] for c in all_cards)),
        "cards": all_cards,
    }

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        json.dump(output, f, indent=2)

    print(f"Generated {len(all_cards)} cards -> {OUTPUT_FILE}")


if __name__ == "__main__":
    generate_json()
