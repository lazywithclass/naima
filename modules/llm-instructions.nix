# modules/llm-instructions.nix
#
# Deploys LLM instruction documents so Claude Code picks them up.
#
# To add more instructions: drop a .md file in llm-instructions/ and
# add its filename to the instructionFiles list below.

{ config, pkgs, lib, ... }:

let
  instructionsDir = ../llm-instructions;

  # Add more instruction files here, they will be automatically picked up and 
  # @-referenced in the generated CLAUDE.md
  instructionFiles = [
    "code-review-guidelines.md"
  ];

  # Generate a CLAUDE.md that @-references every instruction file
  claudeMd = pkgs.writeText "CLAUDE.md" (
    lib.concatMapStringsSep "\n" (f: "@/etc/llm-instructions/${f}") instructionFiles
    + "\n"
  );

in {

  # Deploy each instruction file to /etc/llm-instructions/
  environment.etc = lib.listToAttrs (map (f: {
    name  = "llm-instructions/${f}";
    value = {
      source = instructionsDir + "/${f}";
      mode   = "0444";
    };
  }) instructionFiles);

  # After the project is cloned, symlink CLAUDE.md into it
  systemd.services.llm-instructions-link = {
    description = "Link CLAUDE.md into project directory";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "git-clone-project.service" ];
    requires    = [ "git-clone-project.service" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "link-claude-md" ''
        set -euo pipefail
        if [ ! -d "/srv/project" ]; then
          echo "/srv/project does not exist yet — skipping CLAUDE.md link."
          echo "Will link after git-clone-project succeeds."
          exit 0
        fi
        target="/srv/project/CLAUDE.md"
        # Don't overwrite if the target project has its own CLAUDE.md
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          echo "CLAUDE.md already exists in project (not a symlink), appending @-references..."
          # Append any missing references
          for ref in ${lib.concatMapStringsSep " " (f: "'@/etc/llm-instructions/${f}'") instructionFiles}; do
            ${pkgs.gnugrep}/bin/grep -qF "$ref" "$target" || echo "$ref" >> "$target"
          done
        else
          ln -sf ${claudeMd} "$target"
        fi
      '';
    };
  };
}
