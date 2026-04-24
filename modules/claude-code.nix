# modules/claude-code.nix

{ config, pkgs, lib, ... }:

let
  credStore = "/etc/claude-credentials";
  homeDir   = "/home/naima";
in {

  users.users.naima = {
    isNormalUser = true;
    home         = homeDir;
    description  = "Claude Code service user";
  };

  environment.systemPackages = [ pkgs.claude-code ];

  environment.etc."claude-credentials/session-token.cred" = {
    source = ../secrets/session-token.cred;
    mode   = "0400";
  };

  systemd.services.claude-code-remote = {
    description = "Claude Code remote-control";
    wantedBy    = [ "multi-user.target" ];
    after       = [
      "network-online.target"
      "git-clone-project.service"
    ];
    wants    = [ "network-online.target" "git-clone-project.service" ];

    # Don't fail colmena activation if this service hasn't started yet
    # (placeholder token on first deploy, real token after activate-session.sh)
    restartIfChanged = false;

    serviceConfig = {
      Type       = "simple";
      User       = "naima";
      Group      = "users";
      Restart    = "on-failure";
      RestartSec = "30s";

      LoadCredentialEncrypted =
        "session-token:${credStore}/session-token.cred";

      NoNewPrivileges         = true;
      ProtectSystem           = "full";
      PrivateTmp              = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];

      ExecStartPre = "+${pkgs.writeShellScript "naima-pre" ''
        ${pkgs.coreutils}/bin/mkdir -p /srv/project
        ${pkgs.coreutils}/bin/chown -R naima:users /srv/project
      ''}";
      WorkingDirectory       = "/srv/project";

      ExecStart = pkgs.writeShellScript "naima-start" ''
        set -euo pipefail

        CRED="$CREDENTIALS_DIRECTORY"
        TOKEN=$(cat "$CRED/session-token")

        if [ "$TOKEN" = "placeholder" ]; then
          echo "Session token is a placeholder. Run activate-session.sh to authenticate."
          exit 0
        fi

        mkdir -p ${homeDir}/.claude
        echo "$TOKEN" > ${homeDir}/.claude/.credentials.json
        chmod 600 ${homeDir}/.claude/.credentials.json

        echo "Starting Claude Code remote-control..."
        echo "Session will appear at: https://claude.ai/code"

        (printf 'y\n'; sleep infinity) | ${pkgs.claude-code}/bin/claude remote-control --permission-mode=bypassPermissions --spawn=same-dir
      '';

      ExecStopPost = pkgs.writeShellScript "naima-stop" ''
        rm -f ${homeDir}/.claude/.credentials.json
      '';
    };
  };
}
