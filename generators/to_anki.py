#!/usr/bin/env python3
"""
Generate Anki .apkg deck from YAML content files.
Requires: pip install genanki
"""

import yaml
import re
import hashlib
import genanki
from pathlib import Path

CONTENT_DIR = Path(__file__).parent.parent / "content"
OUTPUT_FILE = Path(__file__).parent.parent / "vg-jargon.apkg"

# Stable IDs derived from deck name
DECK_ID = int(hashlib.md5(b"vg-jargon").hexdigest()[:8], 16)
MODEL_ID = int(hashlib.md5(b"vg-jargon-model").hexdigest()[:8], 16)

# Anki note model with code styling
VG_MODEL = genanki.Model(
    MODEL_ID,
    "VG Jargon",
    fields=[
        {"name": "Front"},
        {"name": "Back"},
        {"name": "Source"},
        {"name": "Tags"},
    ],
    templates=[{
        "name": "Card 1",
        "qfmt": """
            <div class="front">{{Front}}</div>
        """,
        "afmt": """
            <div class="front">{{Front}}</div>
            <hr id="answer">
            <div class="back">{{Back}}</div>
            <div class="source">{{Source}}</div>
        """,
    }],
    css="""
        .card {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 16px;
            text-align: left;
            padding: 20px;
            background: #1e1e1e;
            color: #d4d4d4;
        }
        .front { font-size: 18px; color: #fff; }
        .back { margin-top: 15px; }
        .source {
            margin-top: 20px;
            font-size: 12px;
            color: #666;
            font-style: italic;
        }
        code, pre {
            background: #2d2d2d;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'SF Mono', Monaco, monospace;
            font-size: 14px;
        }
        pre {
            padding: 10px;
            overflow-x: auto;
        }
    """
)


def load_yaml_cards(content_dir: Path) -> list[dict]:
    """Load all cards from YAML files."""
    cards = []

    for yaml_file in content_dir.rglob("*.yaml"):
        if yaml_file.parent.name == "schemas":
            continue

        with open(yaml_file) as f:
            data = yaml.safe_load(f)

        if not data or "cards" not in data:
            continue

        deck = data.get("deck", "vg-jargon")

        for card in data["cards"]:
            card["deck"] = deck
            cards.append(card)

    return cards


def process_cloze(text: str) -> list[tuple[str, str]]:
    """Expand cloze deletions."""
    cloze_pattern = r'\{\{c(\d+)::([^}]+)\}\}'
    matches = list(re.finditer(cloze_pattern, text))

    if not matches:
        return []

    results = []
    cloze_nums = set(m.group(1) for m in matches)

    for num in sorted(cloze_nums):
        front = text
        back = text

        for match in matches:
            cloze_num = match.group(1)
            answer = match.group(2)

            if cloze_num == num:
                front = front.replace(match.group(0), "<b>[...]</b>")
                back = back.replace(match.group(0), f"<b>{answer}</b>")
            else:
                front = front.replace(match.group(0), answer)
                back = back.replace(match.group(0), answer)

        results.append((front.strip(), back.strip()))

    return results


def markdown_to_html(text: str) -> str:
    """Basic markdown to HTML conversion."""
    # Code blocks
    text = re.sub(r'```(\w+)?\n(.*?)```', r'<pre><code>\2</code></pre>', text, flags=re.DOTALL)
    # Inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    # Bold
    text = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', text)
    # Newlines
    text = text.replace('\n', '<br>')
    return text


def card_to_notes(card: dict) -> list[genanki.Note]:
    """Convert a YAML card to Anki note(s)."""
    tags = card.get("tags", [])
    source = card.get("source", "")

    notes = []

    if card["type"] == "basic":
        notes.append(genanki.Note(
            model=VG_MODEL,
            fields=[
                markdown_to_html(card["front"]),
                markdown_to_html(card["back"]),
                source,
                ", ".join(tags),
            ],
            tags=tags,
        ))

    elif card["type"] == "cloze":
        for front, back in process_cloze(card["text"]):
            notes.append(genanki.Note(
                model=VG_MODEL,
                fields=[
                    markdown_to_html(front),
                    markdown_to_html(back),
                    source,
                    ", ".join(tags),
                ],
                tags=tags,
            ))

    elif card["type"] == "reverse":
        notes.append(genanki.Note(
            model=VG_MODEL,
            fields=[
                markdown_to_html(card["front"]),
                markdown_to_html(card["back"]),
                source,
                ", ".join(tags),
            ],
            tags=tags,
        ))
        notes.append(genanki.Note(
            model=VG_MODEL,
            fields=[
                markdown_to_html(card["back"]),
                markdown_to_html(card["front"]),
                source,
                ", ".join(tags),
            ],
            tags=tags + ["reverse"],
        ))

    return notes


def generate_anki():
    """Generate the Anki .apkg file."""
    yaml_cards = load_yaml_cards(CONTENT_DIR)

    deck = genanki.Deck(DECK_ID, "VG Jargon")

    note_count = 0
    for card in yaml_cards:
        for note in card_to_notes(card):
            deck.add_note(note)
            note_count += 1

    genanki.Package(deck).write_to_file(str(OUTPUT_FILE))
    print(f"Generated {note_count} notes -> {OUTPUT_FILE}")


if __name__ == "__main__":
    generate_anki()
