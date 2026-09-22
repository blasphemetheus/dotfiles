# Home Manager Migration

Migrating from GNU Stow to Nix Home Manager + Flakes.

## Why

- Eliminate `sudo cp configuration.nix /etc/nixos/` → just `sudo nixos-rebuild switch --flake .`
- Pinned nixpkgs via flake.lock (reproducible builds)
- Atomic rollbacks that include dotfiles, not just system packages
- One command rebuilds everything (system + user configs)
- Eventually: unlock Hyprland plugins, declarative service management

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Flakes | Yes | Already enabled, eliminates manual config copy |
| Home Manager | NixOS module | Single rebuild for system + user |
| Config strategy | `mkOutOfStoreSymlink` for active configs, `source` for stable ones | Preserves edit→reload workflow for hyprland/waybar/kitty |
| `programs.*` | Only for git, fish, starship | These benefit from shell integration hooks |
| Opacity toggle | Runtime files excluded from HM | `style.css`, `opacity-active.conf`, `opacity-override.conf` managed by script, not Nix |

## New Repo Structure (target)

```
dotfiles/
  flake.nix              # Top-level flake (nixpkgs + home-manager inputs)
  flake.lock             # Auto-generated pinned inputs
  configuration.nix      # System config (existing, minor edits)
  home.nix               # Home Manager user config (NEW)
  hypr/.config/hypr/     # Hyprland configs + scripts (existing)
  waybar/.config/waybar/  # Waybar configs + scripts (existing)
  kitty/.config/kitty/   # Kitty config (existing)
  fish/.config/fish/     # Fish config (existing)
  ... etc
```

## New Rebuild Workflow

```bash
# Instead of:
sudo cp ~/dotfiles/configuration.nix /etc/nixos/configuration.nix
sudo nixos-rebuild switch

# Now:
sudo nixos-rebuild switch --flake ~/dotfiles
# or from dotfiles dir:
sudo nixos-rebuild switch --flake .
```

## Migration Phases

### Phase 1: Flake + Empty Home Manager
Create `flake.nix` and `home.nix`, verify the system builds.

- [x] Create `flake.nix` with nixpkgs + home-manager inputs
- [x] Create minimal `home.nix` (username, homeDirectory, stateVersion)
- [x] Import home-manager as NixOS module in flake
- [x] `sudo nixos-rebuild switch --flake .` succeeds
- [x] System works identically to before

### Phase 2: Migrate Simple Configs
Unstow each package, add to `home.nix` as `xdg.configFile`, rebuild, verify.

- [x] cava
- [x] wob
- [x] helix
- [x] lazygit
- [x] wlogout (layout + style.css)
- [x] rofi (config.rasi + catppuccin.rasi)
- [x] mako

### Phase 3: Migrate Configs with Scripts
These are trickier — scripts directories + runtime-mutable files.

- [x] waybar (config.jsonc, style variants, scripts dir — NOT style.css)
- [x] hypr (hyprland.conf, hypridle, hyprlock, pyprland, hyprshade, scripts — NOT opacity-active.conf)
- [x] kitty (kitty.conf, opacity-override stays runtime-managed)

### Phase 4: Convert to `programs.*`
These benefit from Home Manager's native module integration.

- [x] `programs.git` — delta integration, global ignores
- [x] `programs.fish` — shellAliases, interactiveShellInit, functions
- [x] `programs.starship` — enableFishIntegration, settings from TOML
- [x] `programs.direnv` — enableFishIntegration (removes manual hook)
- [x] `programs.zoxide` — enableFishIntegration (removes manual hook)

### Phase 5: Remaining Configs

- [x] nvim (mkOutOfStoreSymlink — lazy.nvim manages plugins under ~/.local/share)
- [x] ags (mkOutOfStoreSymlink — keeps gitignored node_modules/@girs reachable)
- [x] git global gitignore (via `programs.git.ignores`)

### Phase 6: Cleanup

- [x] Remove `stow` from system packages
- [x] ~~Run `stow -D */`~~ — **not needed**: a deep scan of `~/.config` found zero remaining stow
      symlinks (each phase unstowed as it migrated). Running it would also hit non-package dirs
      (`pkgs/`, `scripts/`, `result/`).
- [x] Update README.md with new setup instructions (also NIXOS-SETUP.md + TESTING.md)
- [ ] ~~Flatten directory layout~~ — **deliberately skipped.** `home.nix` depends on the
      `<app>/.config/<app>/` paths for both `source` copies and `mkOutOfStoreSymlink`; flattening is
      churn with no functional gain.
- [ ] Verify full reboot works cleanly

## Rollback Strategy

| Situation | Fix |
|-----------|-----|
| Build fails | Fix the Nix error, or `git stash` and try again |
| System boots but config broken | `sudo nixos-rebuild switch --rollback` |
| Specific app config broken | `nix shell nixpkgs#stow -c stow <package>` to restore a symlink, remove from home.nix |
| Everything broken | `sudo nixos-rebuild switch --rollback`, then `git checkout` a known-good commit |

(Stow is no longer installed — hence the `nix shell` wrapper above.)

## Key Gotchas

1. **Opacity toggle** writes to `style.css`, `opacity-active.conf`, and `opacity-override.conf` at runtime. Home Manager must NOT manage these (they'd be read-only store symlinks). HM manages the source files they copy from.

2. **`mkOutOfStoreSymlink` requires absolute paths** — must use `"/home/blewf/dotfiles/..."` not relative paths.

3. **Home Manager and Stow conflict** on the same symlink. Unstow before adding to HM, or HM will fail (safely, with a clear error).

4. **NixOS channel must match** Home Manager release branch (e.g., nixos-25.05 with home-manager release-25.05).

## Progress Log

_Updated as we go through each phase._

### Session 1 (2026-03-18)
- Created migration plan
- Decided on flakes + HM as NixOS module + mkOutOfStoreSymlink strategy
- Next: Phase 1 — create flake.nix + home.nix

### Session 2 (2026-07-09)
- Phase 2 complete: cava/wob/helix/lazygit/wlogout/rofi/mako all HM-managed
  (`source`), verified as real dirs with store symlinks inside.
- Phase 3 **staged** in home.nix: hypr, waybar, kitty via
  `config.lib.file.mkOutOfStoreSymlink` (whole-dir, live-edit). Build validated;
  NOT yet activated. To activate:
  ```
  cd ~/dotfiles && stow -D hypr waybar kitty   # drop the old stow symlinks first
  sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka
  ```
  Then confirm `readlink ~/.config/hypr` points into ~/dotfiles and a
  hyprland.conf edit still live-reloads.
- Still stow-linked, remaining: fish (Phase 4 → `programs.fish`), nvim (Phase 5).
- Aside: packaged rwing (Melee replay viewer) in pkgs/rwing.nix + configuration.nix.

### Session 3 (2026-07-09)
- Phase 3 activated (hypr/waybar/kitty out-of-store symlinks; verified live).
- Phase 4 done: `programs.{git,starship,direnv,zoxide,fish}`. starship settings via
  `builtins.fromTOML` on the existing toml (no manual translation). git identity
  left in ~/.gitconfig (sandbox mounts it). Generated config.fish + all functions
  pass `fish --no-execute`.
- Phase 5 done: nvim + ags via mkOutOfStoreSymlink.
- **Everything now HM-managed — stow is only holding the pre-switch symlinks.**
  Activate (build validated):
  ```
  cd ~/dotfiles && stow -D fish git starship nvim ags
  sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka
  ```
- Next: **Phase 6 cleanup** — after a good switch, `stow -D */`, drop `stow` from
  systemPackages, update README. (All 15 packages are migrated.)

### Session 4 (2026-07-09) — Phase 6, migration complete
- Removed `stow` from `configuration.nix` systemPackages.
- `stow -D */` was unnecessary: zero stow symlinks remained (verified by deep scan).
- Rewrote README.md for the flake/HM workflow; de-stowed NIXOS-SETUP.md and TESTING.md
  (the latter still described the pre-flake `sudo cp configuration.nix /etc/nixos` dance).
- Fixed the Rollback table (stow is gone → `nix shell nixpkgs#stow -c stow <pkg>`).
- Skipped the optional directory flattening — see the Phase 6 checklist for why.
- Artifacts to remove by hand (verified stale, no user content): 9 `*.hm-backup` files under
  `~/.config/cava/` (8 identical to repo; the 1 differing file is cava's stock upstream default,
  superseded by the repo's curated Gold-to-Rose config) and the `result` symlink in the repo root
  (a GC root left by `nixos-rebuild build`).
- **Migration complete: all 15 configs Home Manager–managed, Stow retired.**
