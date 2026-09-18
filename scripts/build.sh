#!/bin/bash
# Build script for vg-jargon

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== vg-jargon build ==="

# Generate cards.json
echo "Generating cards.json..."
cd "$PROJECT_DIR"
python3 generators/to_json.py

# Copy to widget resources
cp widget/cards.json widget/VGJargon.swiftpm/Sources/Resources/cards.json 2>/dev/null || true

# Build Swift package (optional)
if command -v swift &> /dev/null; then
    echo "Building Swift package..."
    cd widget/VGJargon.swiftpm
    swift build
else
    echo "Swift not found, skipping build"
fi

echo "Done!"
