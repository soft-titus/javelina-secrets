#!/usr/bin/env bash

set -euo pipefail

KEY_DIR="$HOME/.config/sops/age"
MASTER_KEY_FILE="$KEY_DIR/keys.txt"
SOPS_CONFIG=".sops.yaml"

PUBLIC_KEY_ARG="${1:-}"

if [[ ! -f "$MASTER_KEY_FILE" ]]; then
    echo "Error: Master key file not found: $MASTER_KEY_FILE"
    exit 1
fi

PUBLIC_KEY=""

if [[ -n "$PUBLIC_KEY_ARG" ]]; then
    PUBLIC_KEY="$PUBLIC_KEY_ARG"
else
    if [[ -f "$SOPS_CONFIG" ]]; then
        PUBLIC_KEY=$(grep -m1 'age1' "$SOPS_CONFIG" | grep -o 'age1[0-9a-z]*' || true)
    fi
fi

if [[ -z "$PUBLIC_KEY" ]]; then
    echo "Error: No public key provided and none found in $SOPS_CONFIG"
    exit 1
fi

echo "Using public key '$PUBLIC_KEY'"
echo "Looking for matching private key from the master key list..."

PRIVATE_KEY_BLOCK=$(awk -v pub="$PUBLIC_KEY" '
    /^# created:/ { created=$0 }
    /^# public key:/ { key=$0 }
    /^AGE-SECRET-KEY-/ { priv=$0 }
    key ~ pub { print created "\n" key "\n" priv } 
' "$MASTER_KEY_FILE")

if [[ -z "$PRIVATE_KEY_BLOCK" ]]; then
    echo "Error: Public key $PUBLIC_KEY not found in master key list"
    exit 1
fi

echo "Private key found!"
echo ""

if kubectl -n flux-system get secret sops-age >/dev/null 2>&1; then
    read -rp "Secret flux-system/sops-age exists. Replace it? (y/N): " confirm
    confirm=${confirm:-N}
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborting."
        exit 0
    fi
    echo "Deleting old secret..."
    kubectl -n flux-system delete secret sops-age
fi

TMP_KEY_FILE=$(mktemp)
echo "$PRIVATE_KEY_BLOCK" > "$TMP_KEY_FILE"

echo "Creating new sops-age secret in flux-system..."
kubectl create secret generic sops-age \
    -n flux-system \
    --from-file=age.agekey="$TMP_KEY_FILE"

rm -f "$TMP_KEY_FILE"

echo "Done! Flux can now decrypt SOPS-managed secrets using public key $PUBLIC_KEY."
