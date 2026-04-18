# modules/git-clone.nix

{ config, pkgs, lib, ... }:

let
  repoConfig = builtins.fromJSON (builtins.readFile ../secrets/repo-config.json);
  repoUrl    = repoConfig.url;
  repoBranch = repoConfig.branch;
  repoPath   = "/srv/project";
  credStore  = "/etc/git-credentials";

in {

  environment.etc."git-credentials/deploy-key.cred" = {
    source = ../secrets/deploy-key.cred;
    mode   = "0400";
  };

  systemd.services.git-clone-project = {
    description = "Clone project repo using sealed deploy key";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    before      = [ "claude-code-remote.service" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;

      LoadCredentialEncrypted =
        "deploy-key:${credStore}/deploy-key.cred";

      NoNewPrivileges = true;
      PrivateTmp      = true;
      ProtectHome     = true;
      ReadWritePaths  = [ "/srv" ];
      ProtectSystem   = "full";

      ExecStart = pkgs.writeShellScript "git-clone" ''
        set -euo pipefail

        CRED_DIR="$CREDENTIALS_DIRECTORY"

        # Copy key to writable tmpdir — credential tmpfs is read-only
        KEY_FILE="$(${pkgs.coreutils}/bin/mktemp)"
        ${pkgs.coreutils}/bin/cp "$CRED_DIR/deploy-key" "$KEY_FILE"
        ${pkgs.coreutils}/bin/chmod 600 "$KEY_FILE"
        trap '${pkgs.coreutils}/bin/rm -f "$KEY_FILE"' EXIT

        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh \
          -i $KEY_FILE \
          -o StrictHostKeyChecking=accept-new \
          -o UserKnownHostsFile=/dev/null"

        if [ -d "${repoPath}/.git" ]; then
          echo "Repo exists — pulling latest on ${repoBranch}..."
          ${pkgs.git}/bin/git -C "${repoPath}" pull --ff-only origin "${repoBranch}"
        else
          echo "Cloning ${repoUrl} into ${repoPath}..."
          ${pkgs.coreutils}/bin/mkdir -p /srv
          if ! ${pkgs.git}/bin/git clone --branch "${repoBranch}" "${repoUrl}" "${repoPath}"; then
            echo "Clone failed — deploy key may not be registered on GitHub yet."
            echo "Add the key, then run: systemctl restart git-clone-project"
            exit 0
          fi
          echo "Clone complete."
        fi
      '';
    };
  };
}
