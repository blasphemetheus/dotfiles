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
`configuration.nix` plus an explicit `profiles/laptop.nix` or `profiles/desktop.nix`.
`hosts/<name>/hardware-configuration.nix` is that machine's `nixos-generate-config`
scan. Home Manager modules and app styling are shared; power policy is per profile.

Live-linked configs (hypr, waybar, niri) can't be per-host files, so hardware-specific scripts
check for their hardware and no-op when it is absent (`led-ctl.sh` without OpenRGB,
`hdmi-wake.sh` without the VG27V, `battery-monitor.sh` without a battery, NVIDIA env in
`lua/env.lua` only when the driver is loaded).

Adding a machine: create a host importing `configuration.nix`, its hardware scan,
and the appropriate profile; add one `mkHost` line to `flake.nix` and a host check in
`tests/default.nix`. Keep Aspire's audio patch and hibernation-mode workaround on
the Aspire. A hibernating profile also needs disk swap and `boot.resumeDevice`.

Not in git, so set up by hand on each machine: `~/.config/fish/secrets.fish`, `~/.gitconfig`
identity, the `claude` / `codex` / `devenv` user-profile installs, and the mail password in the
keyring (`secret-tool store`, see `home.nix`).

## Layout

`flake.nix` wires a host module plus `home.nix` (user, via the Home Manager NixOS module). Each
top-level directory holds one app's config in a `<app>/.config/<app>/` layout.

```
flake.nix          - inputs (nixpkgs, home-manager, hyprland…) + one nixosConfiguration per host
hosts/slanka/      - desktop only: NVIDIA, ollama, OpenRGB, monitor-link heals, /data, gaming
hosts/aspire/      - Aspire audio patch, resume device, AMD hibernation workaround
profiles/          - laptop/desktop defaults: power policy, zram, firmware updates
configuration.nix  - shared system: imports, kernel, networking, audio, users
modules/system/    - compositors, login, packages, Nix maintenance, power policy
home.nix           - user: imports, programs.*, email, remaining session services
modules/home/      - Fish, health reporting, notifications, dotfile wiring
pkgs/              - local derivations and flake-input-age command
scripts/           - validation, input-age filter, and hardware/package helpers
tests/             - both-host evaluation/policy checks, input-age regression tests

hypr/   waybar/  kitty/  nvim/  ags/          - live-edit configs (see below)
fish/   git/     starship/                    - now generated from home.nix
cava/   wob/     helix/  lazygit/  wlogout/   - immutable copies
rofi/   mako/
```

## How configs are managed

Three strategies: native program modules in `home.nix`/`modules/home/fish.nix`,
and file sources in `modules/home/dotfiles.nix`:

| Strategy | Apps | Editing workflow |
|---|---|---|
| **`programs.*` module** | fish, git + delta, starship, direnv, zoxide | Edit `home.nix`, `modules/home/fish.nix`, or `starship.toml`, then rebuild |
| **`mkOutOfStoreSymlink`** | hypr, waybar, kitty, nvim, ags | Edit the repo file directly — takes effect on reload, **no rebuild** |
| **`source` (store copy)** | cava, wob, helix, lazygit, wlogout, rofi, mako | Edit the repo file, then rebuild |

The live-edit set is deliberate: those configs are tweaked often, and Home Manager must not own the
runtime-mutable files inside them (the opacity toggle writes into `hypr/`, ags needs its gitignored
`node_modules`).

The shared modules have these boundaries:

| Module | Owns |
|---|---|
| `modules/system/compositors.nix` | Hyprland and plugins, niri/river/dwl sessions, GNOME fallback, X11 settings, cursor, hyprshade resume hook |
| `modules/system/login.nix` | greetd/tuigreet, session menu and greeter assets, hyprlock PAM, polkit agent |
| `modules/home/notifications.nix` | Persistent notification logger, history picker, opt-in DND digest service/timer |
| `modules/home/dotfiles.nix` | App config store copies and live symlinks, including the Mako config file |

System modules are imported by `configuration.nix`; Home Manager modules by
`home.nix`. Host profiles continue to own laptop/desktop policy. Compositor startup
commands and keybindings remain in their app configs; this split preserves their
existing behavior. The hyprshade schedule timer and opt-in agent watchers remain
in `home.nix`.

Git identity lives in `~/.gitconfig` (not managed here — the `sandbox` fish function mounts it).

## Laptop and desktop profiles

| Policy | Laptop | Desktop |
|---|---|---|
| Idle lock | 5 minutes | 25 minutes |
| Screen off | 10 minutes | 15 minutes |
| Idle sleep | 20 minutes | 40 minutes |
| Ordinary sleep | Suspend, then hibernate after 2 hours | Suspend |
| Critical battery (3%) | Hibernate immediately after a 10-second charger recheck | Not applicable |
| Lid close, battery or AC | Suspend, then hibernate | Not configured |
| Docked lid close | Keep running | Not configured |

Laptop idle timings apply on both AC and battery. Override `dotfiles.power.*` in a
host file if needed. `session-sleep` implements ordinary sleep for idle, wlogout,
and the lock screen; `session-sleep critical` implements the low-battery action.
`session-sleep --dry-run [normal|critical]` prints the action without sleeping.
For a future laptop explicitly disabling hibernation, critical battery powers off.
UPower provides a second, system-level action at 2%, using the same hibernate/power-off
policy even when the Hyprland battery monitor is not running.

The active idle config is generated at `/etc/dotfiles/hypridle.conf`. Changes to
profiles or the shared `hypridle.conf` hooks require a rebuild and a hypridle
restart (or a new login). `start-idle.sh` falls back to the old shared defaults
before the first profile rebuild. The Aspire's `HibernateMode=shutdown` workaround
stays in its host module; it is not imposed on every laptop.

`flake-input-age` reports the age of each direct input's **locked source revision**,
following the lockfile's root mappings and `follows` references. Touching/cloning
the lockfile cannot reset those ages. Unknown dates stay unknown. An old revision
does not prove an update exists: deliberately pinned inputs may remain old. Both
the weekly health notification and advisor use this report.

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

## Updating dependencies

Update the rolling inputs together, then validate both hosts:

```sh
nix flake update nixpkgs home-manager ags astal hyprdisplays
./scripts/validate.sh --build
```

The Hyprland stack is deliberately pinned separately. Review its release tags
and plugin compatibility before changing `hyprland`, `aquamarine`, `hyprexpo`,
`hyprsplit`, or `nixpkgs-hypr`; the latter currently supplies the glaze version
required by Hyprland 0.56.2. Updating the main package set does not require
moving those pins. Keep `system.stateVersion` and `home.stateVersion` unchanged.

For kernel or NVIDIA driver updates, prepare a boot generation after successful
validation, then reboot when ready rather than replacing the running graphical
session's userspace libraries mid-session:

```sh
sudo nixos-rebuild boot --flake .#nixos_slanka  # use .#aspire on the laptop
```

After reboot, check login, lock/unlock, suspend/resume, external displays, and
audio on each host. Builds cannot validate these hardware behaviors.

## Testing changes

Run the checks for **both** machines before switching:

```sh
./scripts/validate.sh          # full host evaluation + lightweight flake checks
./scripts/validate.sh --build  # additionally build both systems; never switches
```

New files must be visible to Git (`git add -N <file>` is sufficient) for flakes
to include them. Validation never updates `flake.lock`, sleeps a machine, or runs
the LLM advisor. Full desktop builds still need the private rwing binary described above.

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
