# Dotfiles

Hyprland desktop config with a Gold-to-Rose theme, for NixOS. One repo, one host per machine:
`nixos_slanka` (desktop, RTX 5090) and `aspire` (laptop, Acer Aspire Go 15, AMD iGPU).
Managed declaratively with **Nix flakes + Home Manager** — GNU Stow is no longer used.

## Quick Setup

```fish
git clone <repo-url> ~/dotfiles
sudo nixos-rebuild switch --flake ~/dotfiles   # picks the host matching `hostname`
```

That single command builds the system *and* all user dotfiles. Afterwards the `nrs` abbreviation
is available as a shorthand for the same thing. The first switch on a fresh machine has to name
the host (`--flake ~/dotfiles#aspire`), because the hostname isn't set yet.

See [NIXOS-SETUP.md](NIXOS-SETUP.md) for a full machine setup (NVIDIA GPU, disks, first boot).

## Hosts

`hosts/<name>/default.nix` holds what is tied to one machine and imports the shared
`configuration.nix`; `hosts/<name>/hardware-configuration.nix` is that machine's
`nixos-generate-config` scan. `home.nix` and every app config are shared.

Live-linked configs (hypr, waybar, niri) can't be per-host files, so hardware-specific scripts
check for their hardware and no-op when it is absent (`led-ctl.sh` without OpenRGB,
`hdmi-wake.sh` without the VG27V, `battery-monitor.sh` without a battery, NVIDIA env in
`lua/env.lua` only when the driver is loaded).

Adding a machine: copy `hosts/aspire/`, replace its `hardware-configuration.nix` with the new
scan, and add one `mkHost` line to `flake.nix`.

Not in git, so set up by hand on each machine: `~/.config/fish/secrets.fish`, `~/.gitconfig`
identity, the `claude` / `codex` / `devenv` user-profile installs, and the mail password in the
keyring (`secret-tool store`, see `home.nix`).

## Layout

`flake.nix` wires a host module plus `home.nix` (user, via the Home Manager NixOS module). Each
top-level directory holds one app's config in a `<app>/.config/<app>/` layout.

```
flake.nix          - inputs (nixpkgs, home-manager, hyprland…) + one nixosConfiguration per host
hosts/slanka/      - desktop only: NVIDIA, ollama, OpenRGB, monitor-link heals, /data, gaming
hosts/aspire/      - laptop only: zram, fwupd
configuration.nix  - shared system: kernel, networking, compositors, packages, services
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

## Testing changes

Before switching into a risky change, boot the config in a throwaway VM:

```fish
nixos-rebuild build-vm --flake ~/dotfiles#nixos_slanka   # or #aspire
./result/bin/run-nixos_slanka-vm
rm -f nixos.qcow2 result
```

See [TESTING.md](TESTING.md) for what it can and can't verify (notably: no real GPU).

## Migration history

The Stow → Home Manager migration is documented, phase by phase, in
[HOME-MANAGER-MIGRATION.md](HOME-MANAGER-MIGRATION.md).
