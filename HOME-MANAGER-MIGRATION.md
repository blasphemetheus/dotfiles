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

- [ ] Create `flake.nix` with nixpkgs + home-manager inputs
- [ ] Create minimal `home.nix` (username, homeDirectory, stateVersion)
- [ ] Import home-manager as NixOS module in flake
- [ ] `sudo nixos-rebuild switch --flake .` succeeds
- [ ] System works identically to before

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

- [ ] waybar (config.jsonc, style variants, scripts dir — NOT style.css)
- [ ] hypr (hyprland.conf, hypridle, hyprlock, pyprland, hyprshade, scripts — NOT opacity-active.conf)
- [ ] kitty (kitty.conf, opacity-override stays runtime-managed)

### Phase 4: Convert to `programs.*`
These benefit from Home Manager's native module integration.

- [ ] `programs.git` — delta integration, global ignores
- [ ] `programs.fish` — shellAliases, interactiveShellInit, functions
- [ ] `programs.starship` — enableFishIntegration, settings from TOML
- [ ] `programs.direnv` — enableFishIntegration (removes manual hook)
- [ ] `programs.zoxide` — enableFishIntegration (removes manual hook)

### Phase 5: Remaining Configs

- [ ] nvim (xdg.configFile, NOT programs.neovim — would conflict with lazy.nvim)
- [ ] ags (xdg.configFile)
- [ ] git global gitignore

### Phase 6: Cleanup

- [ ] Remove `stow` from system packages
- [ ] Run `stow -D */` to remove all stow symlinks (HM owns them now)
- [ ] Update README.md with new setup instructions
- [ ] Flatten directory layout if desired (optional)
- [ ] Verify full reboot works cleanly

## Rollback Strategy

| Situation | Fix |
|-----------|-----|
| Build fails | Fix the Nix error, or `git stash` and try again |
| System boots but config broken | `sudo nixos-rebuild switch --rollback` |
| Specific app config broken | `stow <package>` to restore stow symlink, remove from home.nix |
| Everything broken | `git checkout main`, `stow */`, rebuild from `/etc/nixos/configuration.nix` |

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
