# vg-jargon

A flashcard system for learning vg (variation graph toolkit) internals - data structures, algorithms, interfaces, and commands.

## Project Goal

Create Anki-style flashcards covering the vg ecosystem at multiple levels:
- **Interfaces**: HandleGraph, PathHandleGraph, MutableHandleGraph APIs
- **Data structures**: GBZ, GBWT, distance index, snarl tree
- **Algorithms**: Giraffe pipeline (seeding, clustering, chaining, alignment)
- **Commands**: vg subcommands and their options

Output formats:
1. **macOS widget** - Quick flashcard review from menu bar
2. **Anki deck** - Spaced repetition study
3. **JSON** - Portable format for other UIs

## Directory Structure

```
vg-jargon/
├── content/                    # Source of truth - YAML flashcards
│   ├── schemas/
│   │   └── card.schema.json    # Card format validation
│   ├── interfaces/             # HandleGraph API cards
│   ├── data_structures/        # GBZ, distance index, etc.
│   ├── algorithms/             # Giraffe pipeline, etc.
│   └── commands/               # vg CLI commands
├── generators/                 # Build scripts
│   ├── to_json.py             # → widget/cards.json
│   └── to_anki.py             # → vg-jargon.apkg
├── widget/                     # macOS SwiftUI app
│   ├── cards.json             # Generated from content/
│   └── VGJargon/              # Xcode project
└── scripts/
    └── extract_from_repos.py  # Parse source repos → YAML
```

## Card Format

Cards are defined in YAML files under `content/`. Each file has:

```yaml
deck: vg-jargon::category
description: What this file covers
source_repo: libhandlegraph  # Optional

cards:
  - id: prefix-001           # Unique ID
    type: basic|cloze|reverse
    front: Question text
    back: Answer text
    tags: [tag1, tag2]
    difficulty: beginner|intermediate|advanced
    source: path/to/source.hpp  # Optional
```

### Card Types

- **basic**: Front (question) → Back (answer)
- **cloze**: Text with `{{c1::hidden}}` deletions, generates multiple cards
- **reverse**: Creates both front→back and back→front cards

## Source Repositories

Cards are derived from these repos (cloned in `../vgteam_repos/`):

| Repo | Content to Extract |
|------|-------------------|
| `vg.wiki` | Conceptual documentation |

## Generating Output

```bash
# Generate JSON for widget
python3 generators/to_json.py

# Generate Anki deck
pip install genanki pyyaml
python3 generators/to_anki.py
```

## Adding New Cards

1. Find the appropriate YAML file in `content/` (or create one)
2. Add cards following the schema
3. Run `python3 generators/to_json.py` to validate
4. Commit changes

## Widget Architecture

The macOS widget uses:
- **SwiftUI** for UI
- **WidgetKit** for home screen widget
- **cards.json** as data source (generated from YAML)

Features:
- Menu bar app with card browser
- Random card on widget click
- Track review progress locally
- Filter by deck/tag/difficulty

## Key vg Concepts for Cards

### Interfaces (libhandlegraph)
- `HandleGraph` - Base read-only graph interface
- `PathHandleGraph` - Adds path traversal
- `MutableHandleGraph` - Adds modification
- `handle_t` - Opaque node+orientation reference

### Data Structures
- **GBZ** - Compressed graph + haplotypes
- **GBWT** - Graph BWT for haplotype storage
- **Distance Index** - Snarl tree for distance queries
- **Minimizer Index** - K-mer positions for seeding

### Algorithms (Giraffe)
1. Seeding - Find minimizer hits
2. Clustering - Group by distance
3. Chaining - Order into alignments
4. Extension - Full alignment with WFA

## TODO

- [ ] Add more cards from wiki pages
- [ ] Extract method signatures from libhandlegraph headers
- [ ] Add cards for vg CLI commands
- [ ] Create release-notes staging pipeline
