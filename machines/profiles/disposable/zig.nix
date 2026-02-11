{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    lld
    llvmPackages.clang
    zigpkgs.master
  ];
}
