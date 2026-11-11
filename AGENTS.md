# Agent instructions

NixOS + Home Manager flake for two real machines: `nixos_slanka` (desktop) and `aspire`
(laptop). Read [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow; [README.md](README.md)
for layout and how each config is managed. These rules come from them:

- Most files are shared by both machines. Before editing, say which machine(s) the change
  affects. Laptop-only changes go in `hosts/aspire/` or behind
  `config.dotfiles.profile == "laptop"` (`osConfig.dotfiles.profile` in Home Manager).
- Never edit `hosts/slanka/`, any `hardware-configuration.nix`, or a `stateVersion`.
- Never run `nix flake update` or change `flake.lock` unless explicitly asked; the
  Hyprland inputs in `flake.nix` are pinned on purpose (comments there say why).
- Never commit secrets. Keys live in `~/.config/fish/secrets.fish`, outside the repo.
- New files must be visible to Git (`git add -N`) before the flake can see them.
- Verify with `./scripts/validate.sh` (evaluates both hosts, switches nothing). Applying
  a change (`nos` / `nrs`) needs sudo and changes the running system: ask first.
- Contributors work on a branch (`cole/<topic>` or similar) and open a PR; only the
  repo owner (Brad) pushes to `main`.
- Match the existing style: comments explain *why* and record dates of workarounds.
