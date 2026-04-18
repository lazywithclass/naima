# modules/claude-code.nix

{ config, pkgs, lib, ... }:

let
  credStore = "/etc/claude-credentials";
in {

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
      Restart    = "on-failure";
      RestartSec = "30s";

      LoadCredentialEncrypted =
        "session-token:${credStore}/session-token.cred";

      NoNewPrivileges         = true;
      ProtectSystem           = "full";
      PrivateTmp              = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];

      ExecStart = pkgs.writeShellScript "naima-start" ''
        set -euo pipefail

        CRED="$CREDENTIALS_DIRECTORY"
        TOKEN=$(cat "$CRED/session-token")

        if [ "$TOKEN" = "placeholder" ]; then
          echo "Session token is a placeholder. Run activate-session.sh to authenticate."
          exit 0
        fi

        mkdir -p /root/.claude
        echo "$TOKEN" > /root/.claude/.credentials.json
        chmod 600 /root/.claude/.credentials.json

        mkdir -p /srv/project
        cd /srv/project

        echo "Starting Claude Code remote-control..."
        echo "Session will appear at: https://claude.ai/code"

        exec ${pkgs.claude-code}/bin/claude remote-control
      '';

      ExecStopPost = pkgs.writeShellScript "naima-stop" ''
        rm -f /root/.claude/.credentials.json
      '';
    };
  };
}
