import app from "ags/gtk3/app"
import { Gdk } from "ags/gtk3"
import style from "./style.scss"
import Dashboard from "./widget/Dashboard"
import DictationPill from "./widget/DictationPill"

// AGS v3 (aylur/ags flake input — nixpkgs only ships the v2 astal API).
// Dashboard toggles with Super+D (hyprland.conf → `ags toggle dashboard`).

app.start({
  css: style,
  main() {
    const make = (monitor: Gdk.Monitor) => {
      Dashboard(monitor)
      DictationPill(monitor)
    }
    const monitors = app.get_monitors()
    if (monitors.length > 0) {
      make(monitors[0])
    } else {
      // exec-once at login races GDK monitor enumeration — an empty list here
      // is a "not yet", not a "never". Build on the first monitor to appear.
      const id = app.connect("monitor-added", (_app, monitor: Gdk.Monitor) => {
        app.disconnect(id)
        make(monitor)
      })
    }
  },
})
