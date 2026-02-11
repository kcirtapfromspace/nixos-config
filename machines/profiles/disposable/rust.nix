{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cargo
    clang
    openssl
    pkg-config
    rustc
    rustfmt
    rustup
  ];
}
