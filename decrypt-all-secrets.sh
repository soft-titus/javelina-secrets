#!/bin/bash

set -euo pipefail

echo "Decrypting all secrets in folder secrets/"
echo "Decrypted secrets will be saved to raw-secrets/"
echo ""

mkdir -p raw-secrets

shopt -s nullglob
FILES=(secrets/*.yaml)

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No files found in secrets/*.yaml"
    exit 0
fi

for FILE in "${FILES[@]}"; do
    BASENAME=$(basename "$FILE")
    echo "Processing: $FILE"

    if ! grep -q "^sops:" "$FILE"; then
        echo "  - Not encrypted| just copy over"
        cp "$FILE" "raw-secrets/$BASENAME"
        continue
    fi

    echo "  - Decrypting"
    sops -d "$FILE" > "raw-secrets/$BASENAME"
done

echo ""
echo "Done!"
