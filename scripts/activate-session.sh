#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="$REPO_ROOT/secrets"
INSTANCE_IP="$(cat "$SECRETS/instance-ip.txt")"
SSH="ssh -o StrictHostKeyChecking=accept-new root@$INSTANCE_IP"

echo ""
echo "======================================================"
echo "  Activate Claude Code session on $INSTANCE_IP"
echo "======================================================"
echo ""
echo "  1. An SSH session will open on the instance."
echo "  2. Run: claude"
echo "  3. Follow the browser link to authenticate."
echo "  4. Once logged in, type: exit"
echo ""
echo "Press ENTER to connect."
read -r _

ssh -t -o StrictHostKeyChecking=accept-new root@"$INSTANCE_IP" \
  'echo ""; echo "Run: claude"; echo "Authenticate, then type: exit"; echo ""; exec bash --login'

echo ""
echo "Extracting and sealing session token..."
SESSION_JSON=$($SSH cat /root/.claude/.credentials.json 2>/dev/null || true)

if [ -z "$SESSION_JSON" ]; then
  echo "ERROR: ~/.claude/.credentials.json not found."
  echo "  Did you complete the login? Re-run this script."
  exit 1
fi

printf '%s' "$SESSION_JSON" \
  | $SSH "systemd-creds encrypt --name=session-token - -" \
  > "$SECRETS/session-token.cred"
unset SESSION_JSON

echo "Deploying real token and restarting claude-code-remote..."
scp -o StrictHostKeyChecking=accept-new "$SECRETS/session-token.cred" root@"$INSTANCE_IP":/etc/claude-credentials/session-token.cred
$SSH "systemctl restart claude-code-remote"

echo ""
echo "======================================================"
echo "  Session activated. Connect from claude.ai/code."
echo "======================================================"
