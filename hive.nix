# hive.nix — Colmena deployment entry point
{
  meta.nixpkgs = import <nixpkgs> { system = "x86_64-linux"; };

  naima = { name, nodes, pkgs, lib, config, ... }: {

    deployment = {
      targetHost = lib.strings.removeSuffix "\n"
        (builtins.readFile ./secrets/instance-ip.txt);
      targetUser = "root";
      buildOnTarget = true;
      tags = [ "ec2" "remote-dev" ];
    };

    imports = [
      ./modules/base.nix
      ./modules/docker.nix
      ./modules/git-clone.nix
      ./modules/claude-code.nix
      ./modules/llm-instructions.nix
      ./modules/skills.nix
    ];
  };
}
