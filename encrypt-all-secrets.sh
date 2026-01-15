#!/usr/bin/env bash

set -euo pipefail

echo "Encrypting all secrets in secrets/"
echo "Encrypted secrets will be saved in-place in secrets/"
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

    if grep -q "^sops:" "$FILE"; then
        echo "  - Already encrypted | skipping"
        continue
    fi

    echo "  - Encrypting"
    sops -e -i "$FILE"
done

echo ""
echo "Done!"
