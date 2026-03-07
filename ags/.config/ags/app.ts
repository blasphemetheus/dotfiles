import app from "ags/gtk3/app"
import style from "./style.scss"
import Dashboard from "./widget/Dashboard"

app.start({
  css: style,
  main() {
    // Create dashboard for first monitor
    const monitors = app.get_monitors()
    if (monitors.length > 0) {
      Dashboard(monitors[0])
    }
  },
})
