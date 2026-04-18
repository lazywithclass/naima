{ pkgs ? import <nixpkgs> {}}:

pkgs.mkShell {
  packages = [
    pkgs.opentofu
    pkgs.colmena
  ];
}
