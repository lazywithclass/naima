# modules/base.nix — Core NixOS system configuration

{ config, pkgs, lib, ... }:

{
  # ── Boot ──────────────────────────────────────────────────────────────────

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # ── Networking ────────────────────────────────────────────────────────────

  networking = {
    hostName = "naima";
    firewall = {
      enable          = true;
      allowedTCPPorts = [ 22 ];
      # No inbound port needed for Claude Code — outbound HTTPS only.
    };
  };

  # ── SSH ───────────────────────────────────────────────────────────────────

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin        = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # ── Core packages ─────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    jq
    tmux
  ];

  time.timeZone      = "Europe/Rome";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "24.11";
}
