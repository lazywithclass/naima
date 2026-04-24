# container.nix — NixOS module for local testing via nixos-container.
#
# Usage:
#   ./test/test-container.sh
#
# Or manually:
#   sudo nixos-container create naima-test --config-file ./test/container.nix
#   sudo nixos-container start naima-test
#   sudo nixos-container root-login naima-test
#   sudo nixos-container destroy naima-test

{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/docker.nix
    ../modules/git-clone.nix
    ../modules/claude-code.nix
    ../modules/llm-instructions.nix
    ../modules/skills.nix
  ];

  # ── Container overrides ─────────���────────────────────────────────────

  # Docker doesn't work in systemd-nspawn and isn't relevant to skills testing
  virtualisation.docker.enable = lib.mkForce false;

  # The container doesn't need its own firewall or SSH
  networking.firewall.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;

  # ── Stub credential-dependent services ──────────────────��────────────

  # Replace git-clone-project with a stub that just creates /srv/project
  # so downstream services (llm-instructions-link) can still run.
  systemd.services.git-clone-project.serviceConfig = lib.mkForce {
    Type            = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "git-clone-stub" ''
      echo "[Container] git-clone-project skipped (no credentials)"
      mkdir -p /srv/project
    '';
  };

  # Replace claude-code-remote with a no-op
  systemd.services.claude-code-remote.serviceConfig = lib.mkForce {
    Type            = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "claude-code-stub" ''
      echo "[Container] claude-code-remote skipped (no credentials)"
    '';
  };

  # ── Neutralise .cred file deployments ───────────────────────��────────
  # The real modules deploy encrypted blobs to /etc/; override with
  # harmless placeholders so we don't depend on sealed credentials.

  environment.etc."git-credentials/deploy-key.cred" = lib.mkForce {
    text = "placeholder";
    mode = "0400";
  };

  environment.etc."claude-credentials/session-token.cred" = lib.mkForce {
    text = "placeholder";
    mode = "0400";
  };
}
