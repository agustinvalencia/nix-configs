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

          # terminal tools
          pkgs.mkalias
          pkgs.neovim
          pkgs.tmux
          pkgs.git
          pkgs.uv
          pkgs.stow
          pkgs.eza
          pkgs.zoxide
          pkgs.oh-my-posh
          pkgs.fzf
          pkgs.yazi
          pkgs.tree-sitter
          pkgs.nodejs_22
          pkgs.R

          # desktop apps
          pkgs.vscode
          pkgs.obsidian
          pkgs.aerospace
          pkgs.jankyborders
          pkgs.raycast
          pkgs.flameshot # snapshots
          pkgs.zathura # pdf viewer for nvim
          pkgs.maccy # clipboard mgr

          # internet
          pkgs.arc-browser
          pkgs.telegram-desktop
          pkgs.whatsapp-for-mac

          # latex
          pkgs.texliveFull
          pkgs.texlivePackages.latex
          pkgs.texlivePackages.latex-fonts
          pkgs.texlivePackages.bibtex
        ];

      fonts.packages = with pkgs; [
        fira-code
        fira-code-symbols
      ];

      homebrew = {
        enable = true;
        brews = [
          "mas"
        ];
        casks = [
          "ghostty"
          "hiddenbar" 
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
          "${pkgs.arc-browser}/Applications/arc.app"
          "${pkgs.obsidian}/Applications/Obsidian.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        finder.AppleShowAllFiles = true;
        finder.ShowPathbar = true;
        loginwindow.GuestEnabled  = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleShowAllFiles = true;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;

      };

      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      services.jankyborders.enable = true;
      services.jankyborders.active_color = "0x00FF9999";
      services.jankyborders.inactive_color = "0x00FFFFFF";
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
