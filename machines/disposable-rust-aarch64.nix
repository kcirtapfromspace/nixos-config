{ ... }:

{
  imports = [
    ./hardware/vm-aarch64-utm.nix
    ./profiles/disposable/common.nix
    ./profiles/disposable/rust.nix
  ];

  networking.hostName = "disposable-rust-aarch64";

  system.stateVersion = "24.11";
}
