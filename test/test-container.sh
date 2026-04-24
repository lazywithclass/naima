#!/usr/bin/env bash
# test-container.sh — Spin up a local nixos-container to test the NixOS config.
#
# Creates a systemd-nspawn container with the same modules as the real
# deployment, but with credentials and Docker stubbed out. Once inside
# you can inspect /root/.claude/skills/, /etc/claude-skills/, etc.
#
# The container is destroyed on exit.

set -euo pipefail
cd "$(dirname "$0")/.."

CONTAINER_NAME="naima-test"

# ── Ensure stub secrets exist for Nix evaluation ──────────────────────

if [ ! -f secrets/repo-config.json ]; then
  echo "Creating stub secrets/repo-config.json for Nix evaluation..."
  mkdir -p secrets
  echo '{"url":"https://example.com/stub.git","branch":"main"}' > secrets/repo-config.json
fi

# ── Cleanup on exit ─────────���─────────────────────────────────────────

cleanup() {
  echo ""
  echo "Cleaning up container '$CONTAINER_NAME'..."
  sudo nixos-container stop "$CONTAINER_NAME" 2>/dev/null || true
  sudo nixos-container destroy "$CONTAINER_NAME" 2>/dev/null || true
  echo "Done."
}
trap cleanup EXIT

# ── Create and start ──��─────────────────────────────────────���─────────

echo "Building and creating container '$CONTAINER_NAME'..."
sudo nixos-container create "$CONTAINER_NAME" --config-file "$(pwd)/test/container.nix"

echo "Starting container..."
sudo nixos-container start "$CONTAINER_NAME"

echo ""
echo "Container is running. Useful commands once inside:"
echo "  ls /etc/claude-skills/"
echo "  ls /root/.claude/skills/"
echo "  cat /root/.claude/skills/new-branch/SKILL.md"
echo "  ls /etc/llm-instructions/"
echo "  systemctl status claude-skills-link"
echo "  systemctl status llm-instructions-link"
echo "  systemctl status git-clone-project"
echo ""
echo "Type 'exit' or Ctrl-D to leave. The container will be destroyed automatically."
echo ""

sudo nixos-container root-login "$CONTAINER_NAME"
