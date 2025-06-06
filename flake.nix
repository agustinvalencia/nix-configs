{
  description = "AguLabs macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
    configuration = { pkgs, config, ... }: {

      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages =
        [

          # programming
          pkgs.typst
          pkgs.tinymist
          pkgs.rustup

          # latex
          pkgs.texliveFull
          pkgs.texlivePackages.latex
          pkgs.texlivePackages.latex-fonts
          pkgs.texlivePackages.tex-gyre
          pkgs.texlivePackages.bibtex

          # terminal tools
          pkgs.mkalias
          pkgs.git
          pkgs.wget
          pkgs.stow
          pkgs.bat
          pkgs.eza
          pkgs.zoxide
          pkgs.oh-my-posh
          pkgs.fzf
          pkgs.tree-sitter
          pkgs.ripgrep
          pkgs.fd
          pkgs.jq
          pkgs.yq
          pkgs.nodejs_22

          # desktop apps
          pkgs.sketchybar
          pkgs.vscode
          pkgs.obsidian
          pkgs.aerospace
          pkgs.jankyborders
          pkgs.raycast
          pkgs.maccy # clipboard mgr
          pkgs.texstudio
          pkgs.zotero

          # internet
          pkgs.arc-browser
          pkgs.telegram-desktop
          pkgs.whatsapp-for-mac

      ];

      fonts.packages = with pkgs; [
        fira-code
        fira-code-symbols
      ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
          "uv"
          "yazi"
          "neovim"
          "lazygit"
          "tmux"
        ];
        casks = [
          "ghostty"
          "hiddenbar" 
          "hovrly"
          "stats"
          "font-sf-pro"
          "sf-symbols"
        ];
        onActivation.cleanup = "zap";
      };

     system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      system.defaults = {
        loginwindow.GuestEnabled  = false;
        dock.autohide  = true;
        dock.show-recents = false;
        dock.showhidden = true;
        dock.largesize = 64;
        dock.expose-group-apps = true;
        dock.persistent-apps = [
          "/System/Applications/System Settings.app/"
          "/System/Applications/Launchpad.app/"
          "/System/Applications/Mail.app"
          "/System/Applications/Calendar.app"
          "/Applications/Ghostty.app/"
          "/Applications/Spotify.app/"
          "${pkgs.zotero}/Applications/Zotero.app"
          "${pkgs.maccy}/Applications/maccy.app"
          "${pkgs.arc-browser}/Applications/arc.app"
          "${pkgs.obsidian}/Applications/Obsidian.app"
        ];
        # Columns view in finder
        finder.FXPreferredViewStyle = "clmv";
        finder.ShowPathbar = true;
        finder.AppleShowAllFiles = true;
        NSGlobalDomain.AppleShowAllFiles = true;

        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;

        # not show symbols when holding pressed a key
        NSGlobalDomain.ApplePressAndHoldEnabled = false;

      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 4;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    darwinConfigurations."mini" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            # Apple Silicon Only
            enableRosetta = true;
            # User owning the Homebrew prefix
            user = "agustinvalencia";
          };
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."mini".pkgs;
  };
}
