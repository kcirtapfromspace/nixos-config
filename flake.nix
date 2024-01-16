{
  description = "NixOS systems and tools by kcirtap";

  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-23.11-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    # Other packages
    # nixneovim.url = "github:nixneovim/nixneovim";
    # https://github.com/NixNeovim/NixNeovim
    zig.url = "github:mitchellh/zig-overlay";
    # Non-flakes

    fish-foreign-env.flake = false;
    fish-foreign-env.url = "github:oh-my-fish/plugin-foreign-env";
    fish-fzf.flake = false;
    fish-fzf.url = "github:jethrokuan/fzf";
    nvim-treesitter.flake = false;
    nvim-treesitter.url = "github:nvim-treesitter/nvim-treesitter/v0.9.1";
    theme-bobthefish.flake = false;
    theme-bobthefish.url = "github:oh-my-fish/theme-bobthefish";
    tmux-dracula.flake = false;
    tmux-dracula.url = "github:dracula/tmux";
    tmux-pain-control.flake = false;
    tmux-pain-control.url = "github:tmux-plugins/tmux-pain-control";
    tree-sitter-proto.flake = false; 
    tree-sitter-proto.url = "github:mitchellh/tree-sitter-proto"; 
    vim-copilot.flake = false;
    vim-copilot.url = "github:github/copilot.vim/v1.11.1";
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs: let
    # Overlays is the list of overlays we want to apply from flake inputs.
    overlays = [
      inputs.zig.overlays.default
      # inputs.nixneovim.overlays.default
    ];

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };
  in {
    nixosConfigurations.vm-aarch64-utm = mkSystem "vm-aarch64-utm" rec {
      system = "aarch64-linux";
      user   = "kcirtap";
    };

    nixosConfigurations.vm-intel = mkSystem "vm-intel" rec {
      system = "x86_64-linux";
      user   = "kcirtap";
    };

    nixosConfigurations.wsl = mkSystem "wsl" {
      system = "x86_64-linux";
      user   = "kcirtap";
      wsl    = true;
    };

    darwinConfigurations.macbook-pro-m1 = mkSystem "macbook-pro-m1" {
      system = "aarch64-darwin";
      user   = "thinkmac";
      darwin = true;
    };

    darwinConfigurations.thinkstudio = mkSystem "mac-studio-m1" {
      system = "aarch64-darwin";
      user   = "thinkstudio";
      darwin = true;
    };
  };
}