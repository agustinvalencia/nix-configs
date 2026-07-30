# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [nix-darwin](https://github.com/LnL7/nix-darwin) flake configuring a single Apple Silicon Mac mini (`aarch64-darwin`). Everything lives in `flake.nix`; there is no separate module tree. The host is named `mini` (see `darwinConfigurations."mini"`).

The machine is an **always-on MCP HTTP server** — this constraint drives several non-obvious parts of the config (see below).

## Applying changes

```sh
darwin-rebuild switch --flake .#mini    # build and activate the config
```

There are no tests, linters, or build scripts — a successful `darwin-rebuild switch` is the only validation. After editing `flake.nix`, always run it to confirm the config evaluates and activates. Inputs are pinned in `flake.lock`; run `nix flake update` to bump them.

## Where packages come from

Three distinct install channels, all in `flake.nix`. Put a new package in the right one:

- `environment.systemPackages` — nixpkgs CLI tools (reproducible, preferred default).
- `homebrew.brews` — formulae not in nixpkgs or needing Homebrew's build, including this user's custom tap `agustinvalencia/tap` (e.g. `mdvault`, `cuaderno`).
- `homebrew.casks` — GUI apps.

`nix-homebrew` manages the Homebrew prefix declaratively; Homebrew is not used imperatively.

## Critical gotchas (read before editing)

- **`homebrew.onActivation.cleanup = "zap"`**: on every rebuild this *uninstalls and wipes the data* of any cask not listed in `homebrew.casks`. A manually-installed app will be destroyed on the next `darwin-rebuild`. The `orbstack` cask comment documents a real 2026-07-17 incident where this took the remote MCP origin down. Never remove a cask line assuming it's unused, and declare anything installed manually.

- **Power management via `pmset`**: because the mini must never sleep while serving MCP, sleep timers are set through `/usr/bin/pmset` in `system.activationScripts.postActivation` (they have no typed nix-darwin equivalent). Typed `power.restart*` options cover restart-after-failure. Don't "clean up" the pmset script — sleeping the machine takes the server offline.

- **`system.activationScripts.applications`** is overridden with `mkForce` to alias nix-installed GUI apps into `/Applications/Nix Apps` via `mkalias` (Spotlight doesn't index symlinks).

- **`CustomUserPreferences` / `system.defaults`**: several macOS settings (e.g. `AppleSpacesSwitchOnActivate`) are written via `CustomUserPreferences` precisely because they have no typed nix-darwin option — check for an existing typed option before adding one there.

Inline comments in `flake.nix` explain the reasoning for these; preserve them when editing nearby.
