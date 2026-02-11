{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pipx
    poetry
    python3Full
    python3Packages.pip
    uv
  ];
}
