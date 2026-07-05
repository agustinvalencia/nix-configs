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
      system.primaryUser = "agustinvalencia";
        ids.gids.nixbld = 350;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [

        # programming
        pkgs.typst
        pkgs.tinymist
        pkgs.rustup

        # latex
        # pkgs.texliveFull
        # pkgs.texlivePackages.latex
        # pkgs.texlivePackages.latex-fonts
        # pkgs.texlivePackages.tex-gyre
        # pkgs.texlivePackages.bibtex

        # terminal tools
        pkgs.mkalias
        pkgs.kitty
        pkgs.television
        pkgs.git
        pkgs.wget
        pkgs.stow
        pkgs.bun
        pkgs.dust
        pkgs.bat
        pkgs.eza
        pkgs.zoxide
        pkgs.starship
        pkgs.fzf
        pkgs.tree-sitter
        pkgs.ripgrep
        pkgs.just
        pkgs.fd
        pkgs.jq
        pkgs.yq
        pkgs.gh
      ];

      fonts.packages = with pkgs; [
        fira-code
        fira-code-symbols
      ];

      homebrew = {
        enable = true;
        taps = [
          "agustinvalencia/tap"
        ];
        brews = [
          "mas"
          "uv"
          "yazi"
          "lazygit"
          "node"
          "neovim"
          "herdr"
          "hunk"
          "agustinvalencia/tap/cuaderno"
          "agustinvalencia/tap/mdvault"
        ];
        casks = [
          "hiddenbar"
          "hovrly"
          "stats"
          "font-sf-pro"
          "sf-symbols"
          "font-fira-code-nerd-font"
          "obsidian"
          "zotero"
          "skim" 
          "raycast"
          "maccy"
          "whatsapp"
        ];
        onActivation.cleanup = "zap";
      };

     system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = ["/Applications"];
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
        dock = {
            autohide  = true;
            show-recents = false;
            showhidden = true;
            largesize = 64;
            expose-group-apps = true;
            persistent-apps = [
              "/System/Applications/System Settings.app/"
              "/System/Applications/Mail.app"
              "/System/Applications/Calendar.app"
              "${pkgs.kitty}/Applications/kitty.app"
              "/Applications/Spotify.app/"
              "/Applications/Zotero.app"
              "/Applications/Obsidian.app"
              "${pkgs.maccy}/Applications/maccy.app"
              "/Applications/zed.app"
            ];
        };
        # Columns view in finder
        finder = {
            FXPreferredViewStyle = "clmv";
            ShowPathbar = true;
            AppleShowAllFiles = true;
        };
        WindowManager = { EnableStandardClickToShowDesktop = false; };
        NSGlobalDomain.AppleShowAllFiles = true;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
        # not show symbols when holding pressed a key
        NSGlobalDomain.ApplePressAndHoldEnabled = false;

      };

      # Auto upgrade nix package and the daemon service.
      # services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
        nix.gc = {
        automatic = true;
        interval = { Weekday = 0; Hour = 3; Minute = 0; };
        options = "--delete-older-than 30d";
      };

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
        nix-homebrew.darwinModules.nix-homebrew {
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
