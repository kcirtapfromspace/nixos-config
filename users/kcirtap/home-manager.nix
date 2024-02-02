
{ isWSL, inputs, systemType,... }:

{ config, lib, pkgs, ... }:


let
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
  imports = [
    ./neovim.nix
    # ./starship.nix
    # ./terminal.nix
    # ./git.nix
    # ./direnv.nix
    # ./zellij.nix
    # ./nushell.nix
    # ./just.nix
    # ./powershell.nix
  ];

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
    pkgs.shellcheck
    pkgs.tree
    pkgs.watch


    # pkgs.zigpkgs.master

    # Node is required for Copilot.vim
    pkgs.nodejs
  ] ++ (lib.optionals isDarwin [
    # This is automatically setup on Linux
    pkgs.cachix
    pkgs.tailscale
    pkgs.vscode

  ]) ++ (lib.optionals (isLinux && !isWSL) [
    pkgs.chromium
    pkgs.firefox
    pkgs.rofi
    pkgs.valgrind
    pkgs.zathura
    pkgs.xfce.xfce4-terminal
    pkgs.i3
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
    userEmail = "105461352+kcirtapfromspace@users.noreply.github.com";
    signing = {
      key = "";      
      # The default GPG signing key fingerprint.
          # Set to `null` to let GnuPG decide what signing key
          # to use depending on commit’s author."
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
    shell = "${pkgs.fish}/bin/fish";
    terminal = "xterm-256color";
    historyLimit = 100000;
    plugins = with pkgs;
      [
        # {
        #   plugin = tmux-super-fingers;
        #   extraConfig = "set -g @super-fingers-key f";
        # }
        tmuxPlugins.better-mouse-mode
        tmuxPlugins.tmux-thumbs
        tmuxPlugins.yank
        tmuxPlugins.dracula
        tmuxPlugins.pain-control
      ];
    shortcut = "l";
    secureSocket = false;
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"
      set -g default-terminal "tmux-256color"

      set -g prefix ^A
      set -g base-index 1              # start indexing windows at 1 instead of 0
      set -g detach-on-destroy off     # don't exit from tmux when closing a session
      set -g escape-time 0             # zero-out escape time delay
      set -g history-limit 1000000     # increase history size (from 2,000)
      set -g renumber-windows on       # renumber all windows when any window is closed
      set -g set-clipboard on          # use system clipboard
      set -g status-position top       # macOS / darwin style
      setw -g mode-keys vi
      set -g pane-active-border-style 'fg=magenta,bg=default'
      set -g pane-border-style 'fg=brightblack,bg=default'
      set -g @dracula-show-battery false
      set -g @dracula-show-network false
      set -g @dracula-show-weather false

      # set-option -g prefix C-a
      # unbind-key C-b
      # bind-key C-a send-prefix
      set -g mouse on

      # Change splits to match nvim and easier to remember
      # Open new split at cwd of current split
      unbind %i3
      unbind '"'
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Use vim keybindings in copy mode
      set-window-option -g mode-keys vi

      # v in copy mode starts making selection
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Escape turns on copy mode
      bind Escape copy-mode

      # Easier reload of config
      bind r source-file ~/.config/tmux/tmux.conf

      set-option -g status-position top

      # make Prefix p paste the buffer.
      unbind p
      bind p paste-buffer

      # Bind Keys
      bind-key -T prefix C-g split-window \
        "$SHELL --login -i -c 'navi --print | head -c -1 | tmux load-buffer -b tmp - ; tmux paste-buffer -p -t {last} -b tmp -d'"
      bind-key -T prefix C-l switch -t notes
      bind-key -T prefix C-d switch -t dotfiles
      bind-key e send-keys "tmux capture-pane -p -S - | nvim -c 'set buftype=nofile' +" Enter

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
