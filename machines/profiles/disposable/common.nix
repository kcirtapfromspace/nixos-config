{ pkgs, lib, ... }:

{
  # Disposable builders should stay headless and deterministic.
  services.xserver.enable = lib.mkForce false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "0";

  networking.useDHCP = false;
  networking.interfaces.enp0s10.useDHCP = true;
  networking.firewall.enable = false;

  networking.hostName = lib.mkDefault "disposable-builder";
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = true;
    PermitRootLogin = "yes";
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      features = {
        buildkit = true;
      };
      experimental = true;
    };
  };

  environment.variables = {
    REGISTRY_PUSH = lib.mkDefault "localhost:5001";
    REGISTRY_PULL = lib.mkDefault "host.minikube.internal:5001";
  };

  environment.systemPackages = with pkgs; [
    bashInteractive
    cachix
    coreutils
    curl
    docker
    docker-buildx
    git
    gnumake
    jq
    rsync
    skopeo
    unzip
    yq-go
    zstd
  ];

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      keep-outputs = true;
      keep-derivations = true;
      substituters = [ "https://cache.nixos.org" ];
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnsupportedSystem = true;
}
