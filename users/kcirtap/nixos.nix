{ pkgs, inputs, ... }:

{
  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = [ "/share/fish" ];

  # Add ~/.local/bin to PATH
  environment.localBinInPath = true;

  # Since we're using fish as our shell
  programs.fish.enable = true;

  users.users.kcirtap = {
    isNormalUser = true;
    home = "/home/kcirtap";
    extraGroups = [ "docker" "wheel" ];
    shell = pkgs.fish;
    hashedPassword = "$1$sO7N9E9s$ou54gyjRE6gdkXQWs.i0e.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGn/hKs3lZwvDjdvRHjC7YwHeHNNOpEsEh2Cp4ELwEf"
    ];
  };

  nixpkgs.overlays = import ../../lib/overlays.nix ++ [
    # (import ./neovim.nix { inherit inputs pkgs; })
  ];
}
