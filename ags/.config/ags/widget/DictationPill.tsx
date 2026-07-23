import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { createState } from "ags"
import { monitorFile } from "ags/file"
import { interval, Timer } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

// Dictation state pill — floats bottom-center while hyprwhspr-rs is hot.
// State/label logic lives in scripts/dictation-pill.sh ("<style>|<label>"):
// listening (with recording timer), transcribing, done (flashes the inserted
// text), error, hidden. Click-through so it never steals input.
//
// NOT a plain createPoll: a fixed 250ms poll spawned bash ~4×/s FOREVER, even
// while idle (state "hidden", i.e. the vast majority of the time). Over a
// multi-day daemon uptime that leaked the gjs heap to ~50GB and wedged AGS.
// Instead we react to status.json changes via monitorFile (near-zero idle
// cost) and only spin a 1s ticker while something is actually animating — the
// recording timer counts up, and the done-flash counts down ~4s. status.json's
// mtime is stamped once at recording start (the script derives elapsed from
// it), so a file monitor alone can't tick the timer; that's the ticker's job.

const HOME = GLib.get_home_dir()
const SCRIPT = `${HOME}/.config/ags/scripts/dictation-pill.sh`
const STATUS = `${GLib.get_user_cache_dir()}/hyprwhspr-rs/status.json`

const [pill, setPill] = createState("hidden|")

const styleOf = (v: string) => v.slice(0, v.indexOf("|"))
const labelOf = (v: string) => v.slice(v.indexOf("|") + 1)

// The ticker only exists while the pill animates; killed the instant it doesn't.
let ticker: Timer | null = null
function setTicker(on: boolean) {
  if (on && !ticker) {
    ticker = interval(1000, refresh) // fires immediately, then every 1s
  } else if (!on && ticker) {
    ticker.cancel()
    ticker = null
  }
}

function refresh() {
  execAsync(["bash", SCRIPT])
    .then((out) => {
      const v = (out as string).trim() || "hidden|"
      setPill(v)
      // listening → timer ticks up; done → flash counts down. Everything else
      // (transcribing, error, hidden) is static: rest on the file monitor.
      const style = styleOf(v)
      setTicker(style === "listening" || style === "done")
    })
    .catch(() => {
      setPill("hidden|")
      setTicker(false)
    })
}

// React to every state transition hyprwhspr-rs writes; render current state now.
monitorFile(STATUS, () => refresh())
refresh()

export default function DictationPill(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="dictation-pill"
      class="DictationPill"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.BOTTOM}
      marginBottom={18}
      application={app}
      visible={true}
    >
      <box class={pill((v) => `dictation-pill ${styleOf(v)}`)}>
        <label label={pill((v) => labelOf(v))} />
      </box>
    </window>
  )
}
