# Cluster Secrets

Secure storage and management of secrets for the Kubernetes Cluster.

All secrets must be encrypted before being committed to the Git repository.

---

## Requirements
- `age` (installed locally)
- `sops` (installed locally)
- Kubernetes cluster bootstrapped with Flux

---

## 1. Generate AGE Key
Generate a private key for encrypting and decrypting secrets:

```bash
./generate-age-key.sh
```

This will:

- Create / append master keys `~/.config/sops/age/keys.txt` : private key, must be kept secret and never pushed to Git.
- Create / replace `.sops.yaml` : contains the public key, used by SOPS to encrypt secrets.

---

## 2. Import the Private Key Into the Cluster
Cluster must already be bootstrapped with Flux.

```bash
./import-age-key-to-flux.sh
```

This script will find a match private key from the master keys from the public key inside .sops.yaml, then it will create a Kubernetes secret:
- Name: `sops-age`
- Namespace: `flux-system`

Flux uses this private key to decrypt secrets during reconciliation.

---

## 3. Prevent Committing Unencrypted Secrets
Install the pre-commit hook:

```bash
cp hooks/pre-commit .git/hooks/
```

This hook blocks any attempt to commit unencrypted or raw secrets.

---

## 4. Useful SOPS Environment Variables
Add these to your shell profile (e.g. `~/.bashrc`, `~/.zshrc`) so they load automatically:
Tell sops where is your master keys:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

Choose your preferred editor:

```bash
export SOPS_EDITOR='/usr/bin/nano -w'
```

---

## 5. Encrypting Secrets

To encrypt secret you just need .sops.yaml that contains public key, so you can just push this file to repo and share with others who need to encryypt the secret, you don't need to share the private key.

Take note that every secret file need to be encrypted as a wholefrom raw secret, can't encrypt partially.

### Encrypt a single secret:
```bash
sops -e -i secrets/my-secret.yaml
```

### Encrypt all secrets at once:
```bash
./encrypt-all-secrets.sh
```

---

## 6. Decrypting Secrets

To decryypt an encryypted secrets you will need the private key (master keys).

### Decrypt a single secret:
```bash
sops -d secrets/my-secret.yaml > raw-secrets/my-secret.yaml
```

### Decrypt all secrets at once:
```bash
./decrypt-all-secrets.sh
```

---

## 7. Editing an Encrypted Secret

Because sops need to decrypt the secret before you can edit, the private key / master keys is also required here, otherwise you can't edit the encrypted secret, without the private key you need to provide the raw secret as a whole and encrypt it.

```bash
sops secrets/my-secret.yaml
```

SOPS will:
- decrypt the file
- open your editor
- re-encrypt automatically when you save and exit

---

## 8. Key Rotation Procedure
If your key is leaked or you need to rotate keys:

1. Decrypt all existing secrets and create a backup.
2. If the private key has leaked, delete this repository
   (after backing up the decrypted secrets). This removes all
   previously encrypted secrets from Git history, then you can create the new repo with the same structure, provide the secrets you just backup.
3. Generate a new AGE key.
4. Update / make sure `.sops.yaml` contains the new public key.
5. Re-encrypt all secrets using the new key.
6. Import the new private key into the cluster so Flux can decrypt
7. Commit and push the updated encrypted secrets.
8. Manually remove the old private key from master keys.

---

## WARNING
- Never commit private AGE keys to Git
- Never push unencrypted secrets
- Losing the private key means permanent loss of access to all secrets
- Ensure strict RBAC on the `sops-age` secret stored in the `flux-system` namespace
