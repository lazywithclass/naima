#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="$REPO_ROOT/secrets"
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@$INSTANCE_IP"

mkdir -p "$SECRETS"

# 1. Wait for SSH
echo "Waiting for SSH on $INSTANCE_IP..."
until $SSH true 2>/dev/null; do sleep 3; done
echo "SSH ready."

# 2. Seal deploy key
echo "Sealing deploy key..."
printf '%s' "$DEPLOY_KEY" \
  | $SSH "systemd-creds encrypt --name=deploy-key - -" \
  > "$SECRETS/deploy-key.cred"

# 3. Seal placeholder session token (colmena evaluates claude-code.nix which expects this file)
echo "Sealing placeholder session token..."
printf 'placeholder' \
  | $SSH "systemd-creds encrypt --name=session-token - -" \
  > "$SECRETS/session-token.cred"

# 4. Deploy with colmena
echo "Running colmena apply..."
cd "$REPO_ROOT"
COLMENA_SSH_OPTS="-o StrictHostKeyChecking=accept-new" colmena apply --on naima

echo ""
echo "======================================================"
echo "  Provisioning complete."
echo "======================================================"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Add deploy key to GitHub:"
echo "       tofu output deploy_key_public"
echo "     Copy the key to: GitHub -> repo -> Settings -> Deploy keys"
echo ""
echo "  2. Restart git-clone to pick up the key:"
echo "       ssh root@$INSTANCE_IP systemctl restart git-clone-project"
echo ""
echo "  3. Activate Claude session:"
echo "       ./scripts/activate-session.sh"
echo ""
echo "======================================================"
