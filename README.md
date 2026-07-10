# Dotfiles

Hyprland desktop config with a Gold-to-Rose theme, for NixOS (`nixos_slanka`).
Managed declaratively with **Nix flakes + Home Manager** — GNU Stow is no longer used.

## Quick Setup

```fish
git clone <repo-url> ~/dotfiles
sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka
```

That single command builds the system *and* all user dotfiles. Afterwards the `nrs` abbreviation
is available as a shorthand for the same thing.

See [NIXOS-SETUP.md](NIXOS-SETUP.md) for a full machine setup (NVIDIA GPU, disks, first boot).

## Layout

`flake.nix` wires `configuration.nix` (system) and `home.nix` (user, via the Home Manager NixOS
module). Each top-level directory holds one app's config in a `<app>/.config/<app>/` layout.

```
flake.nix          - inputs (nixpkgs, home-manager) + nixosConfigurations.nixos_slanka
configuration.nix  - system: NVIDIA, kernel, networking, packages, services
home.nix           - user: programs.* modules + config file wiring
pkgs/              - local derivations (rwing)
scripts/           - helper scripts (update-rwing.sh, difr-monitor.sh, difr-stress.sh)

hypr/   waybar/  kitty/  nvim/  ags/          - live-edit configs (see below)
fish/   git/     starship/                    - now generated from home.nix
cava/   wob/     helix/  lazygit/  wlogout/   - immutable copies
rofi/   mako/
```

## How configs are managed

Three strategies, chosen per app in `home.nix`:

| Strategy | Apps | Editing workflow |
|---|---|---|
| **`programs.*` module** | fish, git + delta, starship, direnv, zoxide | Edit `home.nix` (or `starship.toml`), then rebuild |
| **`mkOutOfStoreSymlink`** | hypr, waybar, kitty, nvim, ags | Edit the repo file directly — takes effect on reload, **no rebuild** |
| **`source` (store copy)** | cava, wob, helix, lazygit, wlogout, rofi, mako | Edit the repo file, then rebuild |

The live-edit set is deliberate: those configs are tweaked often, and Home Manager must not own the
runtime-mutable files inside them (the opacity toggle writes into `hypr/`, ags needs its gitignored
`node_modules`).

Git identity lives in `~/.gitconfig` (not managed here — the `sandbox` fish function mounts it).

## rwing (Melee replay viewer)

`pkgs/rwing.nix` packages rwing, a **paid, closed-source Patreon binary**. It can't be fetched
automatically, so the binary must be registered in the Nix store once before a from-scratch build:

```fish
nix-store --add-fixed sha256 ~/Downloads/rwing-linux-a2.3
```

To bump to a new release, download the bare `rwing-linux-<ver>` file and run:

```fish
~/dotfiles/scripts/update-rwing.sh ~/Downloads/rwing-linux-<ver>
nrs
```

## Migration history

The Stow → Home Manager migration is documented, phase by phase, in
[HOME-MANAGER-MIGRATION.md](HOME-MANAGER-MIGRATION.md).
