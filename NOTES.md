# Technical Notes

Lessons learned while building this rice. Reference for future changes.

---

## Hyprland 0.54 Syntax

- `windowrulev2` is deprecated. Use `windowrule` blocks with `name` as the first field:
  ```
  windowrule {
      name = my-rule
      match:class = kitty
      opacity = 0.9 0.85
  }
  ```
- Gesture syntax is single-line: `gesture = 3, horizontal, workspace` — NOT a `gestures {}` block
- layerrule blocks use key=value: `blur = true`, `match:namespace = waybar`

## Blur Limitations

- **Blur only works on the `bottom` layer.** Waybar uses `bottom` by default, so it gets blur.
- **`overlay` and `top` layers do NOT get blur.** Mako needs `overlay` to render above windows, so it can't have blur.
- `blurls = namespace` was removed in 0.54 — don't try it
- `ignorealpha` is NOT a valid layerrule block property — don't try it
- `xray = true` breaks layer surface blur (renders solid color). Keep `xray = false`.
- Single-line `layerrule = blur, namespace` does NOT parse in 0.54

### What works:
```
layerrule {
    name = blur-waybar
    match:namespace = waybar
    blur = true
}
```

### Workaround for mako:
Use a dark semi-transparent background (`#1e1c23ee`) with gold border. Looks like dark glass without actual blur.

## NixOS Gotchas

- **No `/bin/bash`** — all scripts must use `#!/usr/bin/env bash`
- **System config is separate** — `configuration.nix` in dotfiles must be copied to `/etc/nixos/` before `nixos-rebuild switch`
- **`killall` not available** — use `pkill` instead
- **wtype required for Wayland typing** — rofimoji defaults to xdotool (X11 only), needs `--action type --typer wtype`

## Waybar

- Config changes require restarting waybar: `pkill waybar; waybar &disown`
- Hyprland reload (`Super+Shift+R`) does NOT reload waybar
- Custom modules using `exec-if` hide the module when the condition is false — if you want a module to stay visible (e.g. paused media), check for broader conditions

## wlogout

- Uses concatenated JSON objects `{} {} {}`, NOT a JSON array `[{}, {}]`

## Dropdown Terminal

- Hyprland special workspaces force-center floating windows, overriding position rules
- Solution: use a toggle script that moves windows between the active workspace and a special workspace
- `hyprctl clients -j` JSON parsing is more reliable with `node` or `jq` than grep patterns
- `movewindowpixel exact 0 0` pins to top-left after moving to workspace
