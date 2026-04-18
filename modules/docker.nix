# modules/docker.nix

{ config, pkgs, lib, ... }:

{
  virtualisation.docker = {
    enable    = true;
    autoPrune = {
      enable = true;
      dates  = "weekly";
      flags  = [ "--filter" "until=168h" ];
    };
    daemon.settings = {
      "log-driver" = "json-file";
      "log-opts"   = { "max-size" = "10m"; "max-file" = "3"; };
    };
  };

  users.users.root.extraGroups = [ "docker" ];

  environment.systemPackages = [ pkgs.docker-compose ];
}
