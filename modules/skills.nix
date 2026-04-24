# modules/skills.nix
#
# Deploys Claude Code skill directories so the remote-control session
# picks them up automatically.
#
# To add a new skill: create a directory under llm-instructions/skills/
# with a SKILL.md file.  It will be discovered and deployed to
# /root/.claude/skills/.

{ config, pkgs, lib, ... }:

let
  skillsDir = ../llm-instructions/skills;

  # Auto-discover skill directories (each must contain a SKILL.md)
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory")
      (builtins.readDir skillsDir)
  );

  # Collect all files for each skill into a flat list of
  # { dest = "skill-name/filename"; src = /path/to/file; }
  skillFiles = lib.concatMap (skill:
    let
      dir = skillsDir + "/${skill}";
      files = builtins.attrNames (
        lib.filterAttrs (_: type: type == "regular")
          (builtins.readDir dir)
      );
    in map (f: {
      dest = "${skill}/${f}";
      src  = dir + "/${f}";
    }) files
  ) skillNames;

in {

  # Deploy each skill file under /etc/claude-skills/ (read-only store)
  environment.etc = lib.listToAttrs (map (entry: {
    name  = "claude-skills/${entry.dest}";
    value = {
      source = entry.src;
      mode   = "0444";
    };
  }) skillFiles);

  # After boot, symlink skill directories into /home/naima/.claude/skills/
  # so Claude Code discovers them.
  systemd.services.claude-skills-link = {
    description = "Link Claude Code skills into /home/naima/.claude/skills/";
    wantedBy    = [ "multi-user.target" ];
    before      = [ "claude-code-remote.service" ];

    serviceConfig = {
      Type            = "oneshot";
      User            = "naima";
      Group           = "users";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "link-claude-skills" ''
        set -euo pipefail
        mkdir -p /home/naima/.claude/skills

        ${lib.concatMapStringsSep "\n" (skill: ''
          # Symlink /etc/claude-skills/${skill} -> /home/naima/.claude/skills/${skill}
          ln -sfn /etc/claude-skills/${skill} /home/naima/.claude/skills/${skill}
        '') skillNames}

        echo "Linked ${toString (builtins.length skillNames)} skill(s) into /home/naima/.claude/skills/"
      '';
    };
  };
}
