#!/usr/bin/env python3
"""
Extract flashcards from vg wiki markdown files.
Outputs YAML files to content/wiki/
"""

import re
import yaml
from pathlib import Path
from dataclasses import dataclass, asdict

WIKI_DIR = Path(__file__).parent.parent.parent / "vgteam_repos" / "vg.wiki"
OUTPUT_DIR = Path(__file__).parent.parent / "content" / "wiki"


@dataclass
class Card:
    id: str
    type: str
    front: str
    back: str
    tags: list
    difficulty: str
    source: str


def parse_markdown_table(text: str) -> list[dict]:
    """Parse a markdown table into a list of dicts."""
    lines = [l.strip() for l in text.strip().split('\n') if l.strip()]
    if len(lines) < 2:
        return []

    # Parse header
    header = [h.strip() for h in lines[0].split('|') if h.strip()]

    # Skip separator line (---)
    rows = []
    for line in lines[2:]:
        if not line or line.startswith('#'):
            break
        cells = [c.strip() for c in line.split('|') if c.strip() or line.count('|') > len(header)]
        # Handle empty cells
        cells = [c.strip() for c in line.split('|')][1:-1] if line.startswith('|') else [c.strip() for c in line.split('|')]
        if len(cells) >= len(header):
            rows.append(dict(zip(header, cells[:len(header)])))

    return rows


def extract_file_types(wiki_dir: Path) -> list[Card]:
    """Extract cards from File-Types.md tables."""
    file_path = wiki_dir / "File-Types.md"
    if not file_path.exists():
        print(f"Warning: {file_path} not found")
        return []

    content = file_path.read_text()
    cards = []
    card_num = 0

    # Find all tables (sections between ## headers)
    sections = re.split(r'^## ', content, flags=re.MULTILINE)

    for section in sections[1:]:  # Skip content before first ##
        lines = section.split('\n')
        section_title = lines[0].strip()
        section_content = '\n'.join(lines[1:])

        # Find table in section
        table_match = re.search(
            r'(Name \| Description.*?)(?=\n\n|\n##|\Z)',
            section_content,
            re.DOTALL
        )

        if not table_match:
            continue

        rows = parse_markdown_table(table_match.group(1))

        for row in rows:
            name = row.get('Name', '').strip()
            desc = row.get('Description', '').strip()
            ext = row.get('Extension', '').strip()
            status = row.get('Status', '').strip()
            notes = row.get('Notes', '').strip()

            if not name or not desc:
                continue

            # Clean up wiki links [[text|link]] -> text
            name = re.sub(r'\[\[([^|\]]+)\|[^\]]+\]\]', r'\1', name)
            name = re.sub(r'\[\[([^\]]+)\]\]', r'\1', name)
            desc = re.sub(r'\[\[([^|\]]+)\|[^\]]+\]\]', r'\1', desc)
            desc = re.sub(r'\[\[([^\]]+)\]\]', r'\1', desc)

            card_num += 1

            # Card: What is [format]?
            back_parts = [desc]
            if ext:
                back_parts.append(f"Extension: {ext}")
            if status:
                back_parts.append(f"Status: {status}")
            if notes:
                back_parts.append(f"Notes: {notes}")

            cards.append(Card(
                id=f"ft-{card_num:03d}",
                type="basic",
                front=f"What is {name}?",
                back='\n'.join(back_parts),
                tags=["file-types", section_title.lower().replace(' ', '-')],
                difficulty="beginner" if status == "Recommended" else "intermediate",
                source="vg.wiki/File-Types.md"
            ))

            # Card: What extension for [format]?
            if ext and ext not in ['?', '']:
                card_num += 1
                cards.append(Card(
                    id=f"ft-{card_num:03d}",
                    type="basic",
                    front=f"What file extension is used for {name}?",
                    back=ext,
                    tags=["file-types", "extensions"],
                    difficulty="beginner",
                    source="vg.wiki/File-Types.md"
                ))

    return cards


def extract_index_types(wiki_dir: Path) -> list[Card]:
    """Extract cards from Index-Types.md."""
    file_path = wiki_dir / "Index-Types.md"
    if not file_path.exists():
        print(f"Warning: {file_path} not found")
        return []

    content = file_path.read_text()
    cards = []
    card_num = 0

    # Find sections with ### headers (index types)
    sections = re.split(r'^### ', content, flags=re.MULTILINE)

    for section in sections[1:]:
        lines = section.split('\n')
        title = lines[0].strip()
        body = '\n'.join(lines[1:]).strip()

        # Get first paragraph as description
        paragraphs = [p.strip() for p in body.split('\n\n') if p.strip()]
        if not paragraphs:
            continue

        desc = paragraphs[0]

        # Clean wiki links
        desc = re.sub(r'\[\[([^|\]]+)\|[^\]]+\]\]', r'\1', desc)
        desc = re.sub(r'\[\[([^\]]+)\]\]', r'\1', desc)

        # Find extension
        ext_match = re.search(r'extension[s]?\s+(?:is|are|for)[^`]*`([^`]+)`', body, re.IGNORECASE)
        ext = ext_match.group(1) if ext_match else ""

        # Find build command
        cmd_match = re.search(r'built with `([^`]+)`', body, re.IGNORECASE)
        cmd = cmd_match.group(1) if cmd_match else ""

        card_num += 1

        # What is [index]?
        back = desc
        if ext:
            back += f"\n\nExtension: `{ext}`"
        if cmd:
            back += f"\nBuild command: `{cmd}`"

        cards.append(Card(
            id=f"idx-{card_num:03d}",
            type="basic",
            front=f"What is the {title} index?",
            back=back,
            tags=["index", title.lower().replace(' ', '-').replace('/', '-')],
            difficulty="intermediate",
            source="vg.wiki/Index-Types.md"
        ))

        # Build command card
        if cmd:
            card_num += 1
            cards.append(Card(
                id=f"idx-{card_num:03d}",
                type="basic",
                front=f"How do you build a {title} index?",
                back=f"`{cmd}`",
                tags=["index", "commands"],
                difficulty="intermediate",
                source="vg.wiki/Index-Types.md"
            ))

    return cards


def extract_snarls_chains(wiki_dir: Path) -> list[Card]:
    """Extract cards from Snarls-and-chains.md."""
    file_path = wiki_dir / "Snarls-and-chains.md"
    if not file_path.exists():
        print(f"Warning: {file_path} not found")
        return []

    content = file_path.read_text()
    cards = []

    # Manual extraction of key definitions
    definitions = [
        {
            "id": "snl-001",
            "front": "What is a snarl?",
            "back": "A topological motif where two or more alternative paths exist between two boundary nodes. A generalization of a 'bubble'. Represents variable sequence flanked by conserved sequence.",
            "tags": ["snarl", "theory", "definition"],
            "difficulty": "intermediate"
        },
        {
            "id": "snl-002",
            "front": "What are the two properties that define a snarl?",
            "back": "1. Separable: splitting boundary nodes disconnects the snarl from the rest of the graph\n2. Minimal: no internal node is separable with the boundary nodes",
            "tags": ["snarl", "theory", "definition"],
            "difficulty": "advanced"
        },
        {
            "id": "snl-003",
            "front": "What is a chain in the snarl decomposition?",
            "back": "A sequence of consecutive snarls with shared boundary nodes between them. For example, if snarl 1-4 and snarl 4-6 share node 4, they form chain 1-6.",
            "tags": ["chain", "snarl", "theory"],
            "difficulty": "intermediate"
        },
        {
            "id": "snl-004",
            "front": "What are the boundary nodes of a snarl?",
            "back": "The two nodes (x and y) that delimit a snarl's subgraph. They are the entry and exit points of the variable region.",
            "tags": ["snarl", "theory"],
            "difficulty": "beginner"
        },
        {
            "id": "snl-005",
            "front": "How is an SNP represented in a variation graph?",
            "back": "Two allele nodes (e.g., nodes 2 and 3) connected between two flanking conserved nodes (e.g., 1 and 4). Forms a simple snarl.",
            "tags": ["snarl", "snp", "variants"],
            "difficulty": "beginner"
        },
        {
            "id": "snl-006",
            "front": "How is an indel represented in a variation graph?",
            "back": "Insertion: a node for inserted sequence between boundary nodes.\nDeletion: an edge bypassing the deleted sequence node.",
            "tags": ["snarl", "indel", "variants"],
            "difficulty": "beginner"
        },
        {
            "id": "snl-007",
            "front": "What is the snarl tree hierarchy (top to bottom)?",
            "back": "1. Root (contains entire graph)\n2. Chains (sequences of connected snarls)\n3. Snarls (bubble structures)\n4. Nodes (leaf level)\n\nChains and snarls alternate in the hierarchy.",
            "tags": ["snarl", "chain", "hierarchy"],
            "difficulty": "intermediate"
        },
        {
            "id": "snl-008",
            "front": "How is a duplication represented in a variation graph?",
            "back": "A node with an edge from its end back to its start (self-loop). A path can traverse the node multiple times.",
            "tags": ["snarl", "duplication", "variants"],
            "difficulty": "intermediate"
        },
        {
            "id": "snl-009",
            "front": "How is an inversion represented in a variation graph?",
            "back": "A node that can be traversed in either direction. Its start and end are each connected to both the previous and next nodes.",
            "tags": ["snarl", "inversion", "variants"],
            "difficulty": "intermediate"
        }
    ]

    for d in definitions:
        cards.append(Card(
            id=d["id"],
            type="basic",
            front=d["front"],
            back=d["back"],
            tags=d["tags"],
            difficulty=d["difficulty"],
            source="vg.wiki/Snarls-and-chains.md"
        ))

    return cards


def extract_giraffe_best_practices(wiki_dir: Path) -> list[Card]:
    """Extract cards from Giraffe-best-practices.md."""
    file_path = wiki_dir / "Giraffe-best-practices.md"
    if not file_path.exists():
        print(f"Warning: {file_path} not found")
        return []

    content = file_path.read_text()
    cards = []

    # Manual extraction of best practices/gotchas
    practices = [
        {
            "id": "gbp-001",
            "front": "What indexes does Giraffe require?",
            "back": "1. GBZ graph (contains GBWT + GBWTGraph)\n2. Distance index (.dist)\n3. Minimizer index (.withzip.min)\n4. Zipcodes file (.zipcodes)",
            "tags": ["giraffe", "indexes", "requirements"],
            "difficulty": "beginner"
        },
        {
            "id": "gbp-002",
            "front": "Why should the distance index be read-only in HPC environments?",
            "back": "As of vg 1.48.0, the distance index is memory-mapped in read+write mode by default. Multiple nodes accessing the same file causes conflicts. Make it read-only or use local copies.",
            "tags": ["giraffe", "hpc", "gotcha"],
            "difficulty": "advanced"
        },
        {
            "id": "gbp-003",
            "front": "What graph structures does Giraffe prefer?",
            "back": "Graphs that avoid complex structures at every level: low-degree nodes, no collapsed repetitive regions, no long-distance edges. Minimize sequence duplication.",
            "tags": ["giraffe", "graphs", "best-practice"],
            "difficulty": "intermediate"
        },
        {
            "id": "gbp-004",
            "front": "How do you specify index files explicitly in Giraffe?",
            "back": "-Z / --gbz-name: GBZ graph\n-d / --dist-name: distance index\n-m / --minimizer-name: minimizer index\n-z / --zipcode-name: zipcodes file",
            "tags": ["giraffe", "commands", "flags"],
            "difficulty": "intermediate"
        },
        {
            "id": "gbp-005",
            "front": "What happens if you don't provide zipcode annotations to Giraffe?",
            "back": "Mapping speed will be slow. Always build the minimizer index with -d (distance index) and -z (zipcode output) options.",
            "tags": ["giraffe", "performance", "gotcha"],
            "difficulty": "intermediate"
        },
        {
            "id": "gbp-006",
            "front": "Difference between short-read and long-read Giraffe indexes?",
            "back": "Different k values for minimizers.\nShort read: .shortread.zipcodes, .shortread.withzip.min\nLong read: .longread.zipcodes, .longread.withzip.min",
            "tags": ["giraffe", "short-read", "long-read"],
            "difficulty": "intermediate"
        },
        {
            "id": "gbp-007",
            "front": "What is the easiest way to build all Giraffe indexes?",
            "back": "`vg autoindex` - automatically builds GBZ, distance index, minimizer index, and zipcodes from input FASTA + VCF.",
            "tags": ["giraffe", "commands", "autoindex"],
            "difficulty": "beginner"
        }
    ]

    for p in practices:
        cards.append(Card(
            id=p["id"],
            type="basic",
            front=p["front"],
            back=p["back"],
            tags=p["tags"],
            difficulty=p["difficulty"],
            source="vg.wiki/Giraffe-best-practices.md"
        ))

    return cards


def write_yaml(cards: list[Card], output_path: Path, deck: str, description: str):
    """Write cards to YAML file."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "deck": deck,
        "description": description,
        "source_repo": "vg.wiki",
        "cards": [asdict(c) for c in cards]
    }

    with open(output_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"Wrote {len(cards)} cards to {output_path}")


def main():
    print(f"Extracting from: {WIKI_DIR}")
    print(f"Output to: {OUTPUT_DIR}")

    # Extract from each source
    file_type_cards = extract_file_types(WIKI_DIR)
    write_yaml(
        file_type_cards,
        OUTPUT_DIR / "file_types.yaml",
        "vg-jargon::wiki::file-types",
        "File formats and extensions in the vg ecosystem"
    )

    index_type_cards = extract_index_types(WIKI_DIR)
    write_yaml(
        index_type_cards,
        OUTPUT_DIR / "index_types.yaml",
        "vg-jargon::wiki::index-types",
        "Index types and build commands"
    )

    snarl_cards = extract_snarls_chains(WIKI_DIR)
    write_yaml(
        snarl_cards,
        OUTPUT_DIR / "snarls_chains.yaml",
        "vg-jargon::wiki::snarls",
        "Snarl and chain theory"
    )

    giraffe_cards = extract_giraffe_best_practices(WIKI_DIR)
    write_yaml(
        giraffe_cards,
        OUTPUT_DIR / "giraffe_best_practices.yaml",
        "vg-jargon::wiki::giraffe",
        "Giraffe best practices and gotchas"
    )

    total = len(file_type_cards) + len(index_type_cards) + len(snarl_cards) + len(giraffe_cards)
    print(f"\nTotal: {total} cards extracted from wiki")


if __name__ == "__main__":
    main()
