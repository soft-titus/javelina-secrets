#!/usr/bin/env bash

set -euo pipefail

KEY_DIR="$HOME/.config/sops/age"
MASTER_KEY_FILE="$KEY_DIR/keys.txt"
TEMP_KEY_FILE="$KEY_DIR/$(date +%s).key"
SOPS_CONFIG=".sops.yaml"

mkdir -p "$KEY_DIR"

echo "Generating AGE key ..."
age-keygen -o "$TEMP_KEY_FILE"

PUBLIC_KEY=$(grep "public key" "$TEMP_KEY_FILE" | sed 's/# public key: //')

if [[ -z "$PUBLIC_KEY" ]]; then
    echo "Failed to extract public key!"
    exit 1
fi

echo "Appending new key to master key lists ..."
cat $TEMP_KEY_FILE >> $MASTER_KEY_FILE
rm $TEMP_KEY_FILE
echo

if [[ -f "$SOPS_CONFIG" ]]; then
    echo "$SOPS_CONFIG already exists."

    read -p "Do you want to overwrite it? (y/N): " confirm
    confirm=${confirm:-N}

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Keeping existing $SOPS_CONFIG. No changes made."
        echo "Done!"
        exit 0
    fi

    echo "Overwriting $SOPS_CONFIG..."
else
    echo "Creating new $SOPS_CONFIG..."
fi

cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: secrets/.*\\.yaml$
    encrypted_regex: ^(data|stringData)$
    age:
      - $PUBLIC_KEY
EOF

echo "Wrote $SOPS_CONFIG with AGE public key."
echo
echo "Done!"
