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

        # diagrams
        # Both render headless. mermaid-cli is deliberately absent: it drives
        # puppeteer and nixpkgs has no chromium on darwin, so mmdc dies with
        # "Could not find Chrome" despite the package evaluating and caching
        # fine.
        #
        # plantuml (~530 MiB, JRE + graphviz, ~1.3s per render) — the one to
        # reach for with sequence diagrams: it puts message labels ABOVE the
        # line and leaves the arrow unbroken.
        #
        # d2 (~60 MiB static Go binary, ~17ms, and `d2 --watch` gives a live
        # preview) — better everywhere else. Its sequence-diagram layout always
        # centres the label ON the connection and hides the line behind it;
        # label.near is silently ignored there, so there is no fixing it.
        #
        # Keep both to SVG. d2's PNG/PDF/PPTX/GIF export tries to install
        # Playwright at runtime and its CDN now 404s — and it exits 0 while
        # producing no file, so check for the output rather than the status.
        pkgs.d2
        pkgs.plantuml

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
        pkgs.pv

        # backup
        # Off-site copy of the cuaderno vault (see the restic-vault-backup
        # launchd agent below). Declared here rather than installed by hand so
        # a rebuild cannot leave the backup agent pointing at a missing binary.
        pkgs.restic
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
          "superfile"
          "herdr"
          "hunk"
          "agustinvalencia/tap/mdvault"
          "agustinvalencia/tap/cuaderno"
        ];
        casks = [
          # Container engine for the vault-anywhere MCP origin. MUST stay
          # declared: onActivation.cleanup = "zap" (below) uninstalls AND
          # wipes the data of any undeclared cask. It was manually installed
          # and got zapped on the 2026-07-17 rebuild, taking the remote MCP
          # origin down until this line was added.
          "orbstack"
          "hovrly"
          "stats"
          "font-sf-pro"
          "sf-symbols"
          "font-fira-code-nerd-font"
          "obsidian"
          "zotero"
          "skim" 
          "maccy"
          "whatsapp"
          "fork"
          "agustinvalencia/tap/cuaderno-app"
        ];
        onActivation.cleanup = "zap";
      };

      # This mini runs as an always-on MCP HTTP server, so it must not sleep.
      # Typed power options cover restart-after-failure; the sleep timers have
      # no typed nix-darwin equivalent and go through pmset in a postActivation
      # script (runs as root on every darwin-rebuild).
      # Off-site vault backup. The vault reaches both Macs within seconds, so
      # they are one failure domain for anything that propagates; the git remote
      # is the only independent copy, and it does not carry `.cuaderno/`
      # (config.toml + templates/ are gitignored as machine-local, yet they are
      # what interprets every note). This agent closes that gap.
      #
      # Credentials are NOT here — this repository is public. The script reads
      # them from ~/.config/restic/vault-r2.env (mode 600) and refuses to run if
      # that file is missing or too permissive.
      launchd.user.agents.restic-vault-backup = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.bash}/bin/bash"
            (toString (pkgs.writeShellScript "restic-vault-backup"
              (builtins.readFile ./scripts/restic-vault-backup.sh)))
          ];
          # launchd agents inherit no PATH from a login shell, so the script
          # would not find restic without this. A terminal test cannot catch it,
          # because there the shell's PATH is already correct.
          EnvironmentVariables = {
            PATH = "${pkgs.restic}/bin:${pkgs.coreutils}/bin:/usr/bin:/bin";
            HOME = "/Users/agustinvalencia";
          };
          # 03:30 daily: the machine never sleeps (see the pmset script), and
          # this is the quietest point for a consistent snapshot.
          StartCalendarInterval = [{ Hour = 3; Minute = 30; }];
          StandardOutPath = "/Users/agustinvalencia/Library/Logs/restic-vault-backup.log";
          StandardErrorPath = "/Users/agustinvalencia/Library/Logs/restic-vault-backup.log";
        };
      };

      power.restartAfterPowerFailure = true;
      power.restartAfterFreeze = true;

      system.activationScripts.postActivation.text = ''
        echo "configuring power management for always-on server..." >&2
        # Never sleep the machine or its disks; the display may still sleep
        # (screen off does not halt the server process).
        /usr/bin/pmset -a sleep 0
        /usr/bin/pmset -a disksleep 0
        /usr/bin/pmset -a powernap 0
        /usr/bin/pmset -a displaysleep 10
      '';

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
        # Distinct from AppleShowAllFiles above (that one is hidden files). This
        # is Finder > Advanced > "Show all filename extensions"; leaving it on
        # makes Spotlight list apps as "Photos.app" instead of "Photos". Was
        # undeclared and had drifted to true on the mini — pinned false so it
        # matches the MacBook and stays that way across rebuilds.
        NSGlobalDomain.AppleShowAllExtensions = false;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
        # not show symbols when holding pressed a key
        NSGlobalDomain.ApplePressAndHoldEnabled = false;

        # Cmd+Tab (and Dock clicks) follow the app to the Space/Desktop that
        # holds its windows, instead of just selecting it in place. Mirrors the
        # Mission Control checkbox "When switching to an application, switch to a
        # Space with open windows for the application". Not a typed NSGlobalDomain
        # option in nix-darwin, so written via CustomUserPreferences.
        CustomUserPreferences.NSGlobalDomain.AppleSpacesSwitchOnActivate = true;

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
