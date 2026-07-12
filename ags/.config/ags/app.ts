import { App } from "astal/gtk3"
import style from "./style.scss"
import DictationPill from "./widget/DictationPill"

// NOTE: Dashboard.tsx is written for AGS v3 (`ags/gtk3` imports, createPoll)
// but nixpkgs ships AGS v2.3 whose library is `astal` — the dashboard has
// never actually run on this machine (it also still calls /home/dori paths).
// Reviving it means adding the aylur/ags v3 flake input and porting, or
// rewriting it against the v2 API like DictationPill below.
// import Dashboard from "./widget/Dashboard"

App.start({
  css: style,
  main() {
    const monitors = App.get_monitors()
    if (monitors.length > 0) {
      DictationPill(monitors[0])
    }
  },
})
