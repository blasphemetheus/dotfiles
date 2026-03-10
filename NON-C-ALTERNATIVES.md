# Non-C Alternatives for the Linux Desktop Stack

Reference for replacing C/C++ tools with Rust, Zig, Go, and other languages.
Based on current setup: NixOS + Hyprland + RTX 5090.

## Current Stack (what you have now)

| Role              | Tool           | Language   |
|-------------------|----------------|------------|
| Compositor        | Hyprland       | C++        |
| Display Manager   | greetd/tuigreet| **Rust**   |
| Bar               | waybar         | C++        |
| Wallpaper         | swww           | **Rust**   |
| Lock screen       | hyprlock       | C++        |
| Launcher          | rofi/wofi      | C          |
| Notifications     | mako           | C          |
| Terminal          | kitty          | C/Python   |
| Shell             | fish           | C++        |
| File manager      | dolphin        | C++/Qt     |
| Editor            | helix          | **Rust**   |
| Editor            | neovim         | C/Lua      |
| Git TUI           | lazygit        | **Go**     |
| Power menu        | wlogout        | C          |
| Audio visualizer  | cava           | C          |
| cat               | bat            | **Rust**   |
| ls                | eza            | **Rust**   |
| find              | fd             | **Rust**   |
| grep              | ripgrep        | **Rust**   |
| diff              | delta          | **Rust**   |
| du                | dust           | **Rust**   |
| ps                | procs          | **Rust**   |
| cd                | zoxide         | **Rust**   |
| System info       | fastfetch      | C          |
| System monitor    | btop           | C++        |

---

## Compositors (Wayland WMs)

| Project     | Language   | Notes                                           |
|-------------|------------|-------------------------------------------------|
| **niri**    | **Rust**   | Scrollable tiling compositor. Unique UX, active. |
| **Smithay** | **Rust**   | Compositor *library* — build your own WM.       |
| **COSMIC**  | **Rust**   | System76's full desktop environment. Big project.|
| **River**   | **Zig**    | Tiling Wayland compositor. Clean, minimal.       |

> River (Zig) and niri (Rust) are the most realistic "throw Claude at it" options
> if you want to hack on a compositor. Smithay is the library if you want to
> build one from scratch.

## Display Managers / Greeters

| Project      | Language   | Notes                                        |
|--------------|------------|----------------------------------------------|
| **greetd**   | **Rust**   | Minimal login daemon. Pairs with greeters.   |
| **tuigreet** | **Rust**   | TUI greeter for greetd.                      |
| **regreet**  | **Rust**   | GTK4 greeter for greetd.                     |
| **Lemurs**   | **Rust**   | Standalone TUI display manager.              |
| **Ly**       | **Zig**    | TUI display manager. Small, hackable.        |

NixOS snippet for greetd + tuigreet:
```nix
services.greetd = {
  enable = true;
  settings.default_session = {
    command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd Hyprland";
    user = "greeter";
  };
};
```

## Bars / Panels

| Project     | Language   | Notes                                           |
|-------------|------------|-------------------------------------------------|
| **ironbar** | **Rust**   | Wayland bar, config-driven. Hyprland support.   |
| **eww**     | **Rust**   | "ElKowars Wacky Widgets" — scriptable widgets.  |

## Launchers

| Project    | Language   | Notes                                            |
|------------|------------|--------------------------------------------------|
| **anyrun** | **Rust**   | Wayland-native launcher, plugin system.          |
| **onagre** | **Rust**   | Launcher inspired by rofi, Wayland-native.       |
| **walker** | **Go**     | Application launcher for Wayland.                |

## Lock Screens

| Project     | Language   | Notes                             |
|-------------|------------|-----------------------------------|
| **waylock** | **Zig**    | Screen locker for Wayland.        |

## Notification Daemons

| Project  | Language   | Notes                                              |
|----------|------------|----------------------------------------------------|
| **swaync** | **Vala** | SwayNotificationCenter — feature-rich, panel style.|

> mako (C) is solid and lightweight. swaync is the main non-C alternative
> if you want more features.

## Terminals

| Project       | Language   | Notes                                         |
|---------------|------------|-----------------------------------------------|
| **alacritty** | **Rust**   | GPU-accelerated, minimal config.              |
| **wezterm**   | **Rust**   | GPU-accelerated, Lua-configurable, multiplexer built in. |
| **rio**       | **Rust**   | GPU-accelerated, newer.                       |
| **Ghostty**   | **Zig**    | By Mitchell Hashimoto (HashiCorp). Fast, native. |

## Shells

| Project    | Language   | Notes                                           |
|------------|------------|-------------------------------------------------|
| **nushell** | **Rust**  | Structured data shell. Pipelines return tables. |

## File Managers

| Project  | Language   | Notes                                     |
|----------|------------|-------------------------------------------|
| **yazi** | **Rust**   | Blazing fast TUI file manager. Async I/O. |

## Terminal Multiplexers

| Project   | Language   | Notes                                        |
|-----------|------------|----------------------------------------------|
| **zellij** | **Rust** | Modern tmux alternative. Plugin system (WASM).|

## CLI Tools (Rust rewrites)

These replace common C/C++ utilities:

| Tool          | Replaces   | Language   |
|---------------|------------|------------|
| **bat**       | cat        | Rust       |
| **eza**       | ls         | Rust       |
| **fd**        | find       | Rust       |
| **ripgrep**   | grep       | Rust       |
| **sd**        | sed        | Rust       |
| **dust**      | du         | Rust       |
| **bottom**    | top/htop   | Rust       |
| **procs**     | ps         | Rust       |
| **starship**  | prompt     | Rust       |
| **tokei**     | cloc       | Rust       |
| **gitui**     | lazygit    | Rust       |
| **delta**     | diff       | Rust       |
| **just**      | make       | Rust       |
| **zoxide**    | cd (smart) | Rust       |

## Editors / IDEs

| Project  | Language   | Notes                                    |
|----------|------------|------------------------------------------|
| **helix** | **Rust** | Already using. Modal, LSP-first.          |
| **zed**   | **Rust** | GPU-accelerated editor/IDE. Collaborative.|
| **lapce** | **Rust** | Lightning fast, plugin system (WASM).     |

---

## Languages Summary

| Language  | Strongest in                                    |
|-----------|-------------------------------------------------|
| **Rust**  | Everything. Biggest ecosystem for replacements. |
| **Zig**   | Compositors (River), DMs (Ly), terminals (Ghostty), lock (waylock). |
| **Go**    | Launchers, CLI tools, lazygit.                  |
| **Vala**  | GNOME-adjacent tools (swaync).                  |

## "Throw Claude at it" Tier List

**Most hackable (smaller codebases, focused scope):**
- Ly (Zig) — display manager
- waylock (Zig) — lock screen
- Lemurs (Rust) — display manager
- anyrun (Rust) — launcher

**Medium projects:**
- River (Zig) — compositor
- niri (Rust) — compositor
- ironbar (Rust) — bar
- yazi (Rust) — file manager

**Big projects (contribute, don't rewrite):**
- COSMIC (Rust) — full DE
- Ghostty (Zig) — terminal
- zed (Rust) — editor
