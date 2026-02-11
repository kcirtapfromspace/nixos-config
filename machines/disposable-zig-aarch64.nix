{ ... }:

{
  imports = [
    ./hardware/vm-aarch64-utm.nix
    ./profiles/disposable/common.nix
    ./profiles/disposable/zig.nix
  ];

  networking.hostName = "disposable-zig-aarch64";

  system.stateVersion = "24.11";
}
