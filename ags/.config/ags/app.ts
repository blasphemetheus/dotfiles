import app from "ags/gtk3/app"
import style from "./style.scss"
import Dashboard from "./widget/Dashboard"
import DictationPill from "./widget/DictationPill"

// AGS v3 (aylur/ags flake input — nixpkgs only ships the v2 astal API).
// Dashboard toggles with Super+D (hyprland.conf → `ags toggle dashboard`).

app.start({
  css: style,
  main() {
    const monitors = app.get_monitors()
    if (monitors.length > 0) {
      Dashboard(monitors[0])
      DictationPill(monitors[0])
    }
  },
})
