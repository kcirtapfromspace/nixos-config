{ config, pkgs, lib, ... }: {
  # We install Nix using a separate installer so we don't want nix-darwin
  # to manage it for us. This tells nix-darwin to just use whatever is running.
  # nix.useDaemon = true;

  nix = {
    # We need to enable flakes
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    settings = {
      auto-optimise-store = false;
      substituters = ["https://kcirtapfromspace-nixos-config.cachix.org"];
      trusted-public-keys = ["kcirtapfromspace-nixos-config.cachix.org-1:WvCbexA5U/18jpd+S1Xdl83HIRkibSQJdSUXWfQpz00="];
    };
  };
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Use the nix daemon
  nix.enable = true;

  programs.nix-index.enable = true;

  # do garbage collection weekly to keep disk usage low
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 7d";
  };

  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
    # public binary cache that I use for all my derivations. You can keep
    # this, use your own, or toss it. Its typically safe to use a binary cache
    # since the data inside is checksummed.
    # https://app.cachix.org/cache/kcirtapfromspace-nixos-config#pull
    # substituters = https://cache.nixos.org https://cache.nixos.org/ https://kcirtapfromspace-nixos-config.cachix.org
    # trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=", "kcirtapfromspace-nixos-config.cachix.org-1:WvCbexA5U/18jpd+S1Xdl83HIRkibSQJdSUXWfQpz00="



  # zsh is the default shell on Mac and we want to make sure that we're
  # configuring the rc correctly with nix-darwin paths.
  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
    '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    # Nix
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
    # End Nix
    '';

  system.stateVersion = 5;

  environment.shells = with pkgs; [ bashInteractive zsh fish ];
  environment.systemPackages = with pkgs; [
    cachix
    git
  ];
}
