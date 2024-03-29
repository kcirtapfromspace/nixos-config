
{ isWSL, inputs, systemType,... }:

{ config, lib, pkgs, ... }:


let

  _ = builtins.trace "Current system type is: ${systemType}";

  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;

  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  manpager = (pkgs.writeShellScriptBin "manpager" (if isDarwin then ''
    sh -c 'col -bx | bat -l man -p'
    '' else ''
    cat "$1" | col -bx | bat --language man --style plain
  ''));
in {
  # Home-manager 22.11 requires this be set. We never set it so we have
  # to use the old state version.
  home.stateVersion = "23.11";
  
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------

  # Packages I always want installed. Most packages I install using
  # per-project flakes sourced with direnv and nix-shell, so this is
  # not a huge list.

  home.packages = with pkgs; [
  # Common packages here
  # x86_64 specific packages
  ] ++ lib.optionals (systemType == "x86_64-linux") [
  # aarch64 specific packages
  ] ++ lib.optionals (systemType == "aarch64-linux") [
  ] ++ lib.optionals (systemType == "aarch64-darwin") [
    pkgs._1password
    pkgs._1password-gui
    pkgs.asciinema
    pkgs.awscli
    pkgs.bat
    pkgs.bottom
    pkgs.brotli
    pkgs.ctags
    pkgs.curl
    pkgs.direnv
    pkgs.direnv
    pkgs.docker
    pkgs.entr
    pkgs.eza
    pkgs.fd
    pkgs.fira-code
    pkgs.fira-code-nerdfont
    pkgs.fira-code-symbols
    pkgs.fzf
    pkgs.gettext
    pkgs.gh
    pkgs.gnupg
    pkgs.gopls
    pkgs.htop
    pkgs.jq
    pkgs.kitty
    pkgs.mosh
    pkgs.podman
    pkgs.qes
    pkgs.ripgrep
    pkgs.ripgrep
    pkgs.shellcheck
    pkgs.tree
    pkgs.vscode
    pkgs.watch
    pkgs.zsh-completions
    # pkgs.zigpkgs.master

    # Node is required for Copilot.vim
    pkgs.nodejs
  ] ++ (lib.optionals isDarwin [
    # This is automatically setup on Linux
    pkgs.cachix
    pkgs.tailscale

  ]) ++ (lib.optionals (isLinux && !isWSL) [
    pkgs.chromium
    pkgs.firefox
    pkgs.rofi
    pkgs.valgrind
    pkgs.zathura
    pkgs.xfce.xfce4-terminal
  ]);

  #---------------------------------------------------------------------
  # Env vars and dotfiles
  #---------------------------------------------------------------------

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
  };

  home.file.".gdbinit".source = ./gdbinit;
  home.file.".inputrc".source = ./inputrc;

  xdg.configFile = {
    "i3/config".text = builtins.readFile ./i3;
    "rofi/config.rasi".text = builtins.readFile ./rofi;

    # tree-sitter parsers
    # "nvim/parser/proto.so".source = "${pkgs.tree-sitter-proto}/parser";
    # "nvim/queries/proto/folds.scm".source =
    #   "${inputs.tree-sitter-proto.packages.${systemType}.tree-sitter-proto}/queries/folds.scm";
    # "nvim/queries/proto/highlights.scm".source = 
    #   "${inputs.tree-sitter-proto.packages.${systemType}.tree-sitter-proto}/queries/highlights.scm";

    "nvim/queries/proto/textobjects.scm".source =
      ./textobjects.scm;
  } // (if isDarwin then {
    # Rectangle.app. This has to be imported manually using the app.
    "rectangle/RectangleConfig.json".text = builtins.readFile ./RectangleConfig.json;
  } else {}) // (if isLinux then {
    "ghostty/config".text = builtins.readFile ./ghostty.linux;
  } else {});

  #---------------------------------------------------------------------
  # Programs
  #---------------------------------------------------------------------

  programs.gpg.enable = !isDarwin;

  programs.bash = {
    enable = true;
    shellOptions = [];
    historyControl = [ "ignoredups" "ignorespace" ];
    initExtra = builtins.readFile ./bashrc;

    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
    };
  };

  programs.direnv= {
    enable = true;

    config = {
      whitelist = {
        prefix= [
          "$HOME/code/go/src/github.com/hashicorp"
          "$HOME/code/go/src/github.com/kcirtapfromspace"
        ];

        exact = ["$HOME/.envrc"];
      };
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" ([
      # "source ${inputs.theme-bobthefish.packages.${systemType}.theme-bobthefish}/functions/fish_prompt.fish"
      # "source ${inputs.theme-bobthefish.packages.${systemType}.theme-bobthefish}/functions/fish_right_prompt.fish"
      # "source ${inputs.theme-bobthefish.packages.${systemType}.theme-bobthefish}/functions/fish_title.fish"
      (builtins.readFile ./config.fish)
      "set -g SHELL ${pkgs.fish}/bin/fish"
    ]));

    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
    } // (if isLinux then {
      # Two decades of using a Mac has made this such a strong memory
      # that I'm just going to keep it consistent.
      pbcopy = "xclip";
      pbpaste = "xclip -o";
    } else {});

  #   plugins = map (n: {
  #     name = n;
  #     src = inputs.${n}.packages.${systemType}.${n};
  #     }) [
  #     "fish-fzf"
  #     "fish-foreign-env"
  #     "theme-bobthefish"
  #   ];
  };

  programs.git = {
    enable = true;
    userName = "Patrick Deutsch";
    userEmail = "patrick.deutsch@gmail.com";
    signing = {
      key = "523D5DC389D273BC";
      signByDefault = true;
    };
    aliases = {
      cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 -r git branch -d";
      prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      root = "rev-parse --show-toplevel";
    };
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
      core.askPass = ""; # needs to be empty to use terminal for ask pass
      credential.helper = "store"; # want to make this more secure
      github.user = "kcirtapfromspace";
      push.default = "tracking";
      init.defaultBranch = "main";
    };
  };

  programs.go = {
    enable = true;
    goPath = "code/go";
    goPrivate = [ "github.com/kcirtapfromspace" "github.com/hashicorp" "rfc822.mx" ];
  };
#TODO: fix this tmux extra config
    # run-shell ${inputs.tmux-pain-control.packages.${systemType}.tmux-pain-control}/pain_control.tmux
    # run-shell ${inputs.tmux-dracula.packages.${systemType}.tmux-dracula}/dracula.tmux
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    shortcut = "l";
    secureSocket = false;

    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"

      set -g @dracula-show-battery false
      set -g @dracula-show-network false
      set -g @dracula-show-weather false

      bind -n C-k send-keys "clear"\; send-keys "Enter"


    '';
  };

  programs.alacritty = {
    enable = !isWSL;

    settings = {
      env.TERM = "xterm-256color";

      key_bindings = [
        { key = "K"; mods = "Command"; chars = "ClearHistory"; }
        { key = "V"; mods = "Command"; action = "Paste"; }
        { key = "C"; mods = "Command"; action = "Copy"; }
        { key = "Key0"; mods = "Command"; action = "ResetFontSize"; }
        { key = "Equals"; mods = "Command"; action = "IncreaseFontSize"; }
        { key = "Subtract"; mods = "Command"; action = "DecreaseFontSize"; }
      ];
    };
  };

  programs.kitty = {
    enable = !isWSL;
    extraConfig = builtins.readFile ./kitty;
  };

  programs.i3status = {
    enable = isLinux && !isWSL;

    general = {
      colors = true;
      color_good = "#8C9440";
      color_bad = "#A54242";
      color_degraded = "#DE935F";
    };

    modules = {
      ipv6.enable = false;
      "wireless _first_".enable = false;
      "battery all".enable = false;
    };
  };

  programs.neovim = {
    enable = true;
    # package = pkgs.neovim-nightly;

    withPython3 = true;

    # plugins = with pkgs; [
    #   customVim.vim-copilot
    #   customVim.vim-cue
    #   customVim.vim-fish
    #   customVim.vim-fugitive
    #   customVim.vim-glsl
    #   customVim.vim-misc
    #   customVim.vim-pgsql
    #   customVim.vim-tla
    #   customVim.vim-zig
    #   customVim.pigeon
    #   customVim.AfterColors

    #   customVim.vim-nord
    #   customVim.nvim-comment
    #   customVim.nvim-lspconfig
    #   customVim.nvim-plenary # required for telescope
    #   customVim.nvim-telescope
    #   customVim.nvim-treesitter
    #   customVim.nvim-treesitter-playground
    #   customVim.nvim-treesitter-textobjects

    #   vimPlugins.vim-airline
    #   vimPlugins.vim-airline-themes
    #   vimPlugins.vim-eunuch
    #   vimPlugins.vim-gitgutter

    #   vimPlugins.vim-markdown
    #   vimPlugins.vim-nix
    #   vimPlugins.typescript-vim
    #   vimPlugins.nvim-treesitter-parsers.elixir
    # ] ++ (lib.optionals (!isWSL) [
    #   # This is causing a segfaulting while building our installer
    #   # for WSL so just disable it for now. This is a pretty
    #   # unimportant plugin anyway.
    #   customVim.vim-devicons
    # ]);

    # extraConfig = (import ./vim-config.nix) {
      # inherit inputs systemType;
    # };
  };

  services.gpg-agent = {
    enable = isLinux;
    pinentryFlavor = "tty";

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  xresources.extraConfig = builtins.readFile ./Xresources;

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
