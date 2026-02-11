{ ... }:

{
  imports = [
    ./hardware/vm-aarch64-utm.nix
    ./profiles/disposable/common.nix
    ./profiles/disposable/python.nix
  ];

  networking.hostName = "disposable-python-aarch64";

  system.stateVersion = "24.11";
}
