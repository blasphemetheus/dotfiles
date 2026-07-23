import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { createState } from "ags"
import { monitorFile } from "ags/file"
import { interval, Timer } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

// Screen-recording pill — floats top-center while wf-recorder runs, counting
// elapsed time; click it to stop (runs the same toggle script). State source is
// scripts/recording-pill.sh ("<style>|<label>"), driven by `pgrep wf-recorder`
// plus a start-epoch stamp the toggle writes to $XDG_RUNTIME_DIR/screen-record.
//
// Same shape as DictationPill (monitorFile + a 1s ticker only while active) to
// avoid the forever-poll gjs heap leak documented there. One wrinkle: a process
// exit is NOT a file event, so when wf-recorder dies (SIGINT from the stop
// click, or a crash) the file monitor won't fire — the ticker is what re-runs
// the script every 1s, notices the process is gone, and hides the pill.

const HOME = GLib.get_home_dir()
const SCRIPT = `${HOME}/.config/ags/scripts/recording-pill.sh`
const TOGGLE = `${HOME}/.config/ags/scripts/screen-record-toggle.sh`
const STATE = `${GLib.get_user_runtime_dir()}/screen-record/state`

const [pill, setPill] = createState("hidden|")

const styleOf = (v: string) => v.slice(0, v.indexOf("|"))
const labelOf = (v: string) => v.slice(v.indexOf("|") + 1)

// The ticker exists only while recording; killed the instant it stops.
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
      setTicker(styleOf(v) === "recording")
    })
    .catch(() => {
      // A transient bash-spawn failure must NOT hide the pill mid-recording:
      // if the ticker is live we're recording, so keep the current pill and let
      // the next tick re-check. Only hide when idle (monitor-driven, no ticker).
      if (!ticker) setPill("hidden|")
    })
}

// Fires when the toggle stamps/clears the state file; render current state now.
monitorFile(STATE, () => refresh())
refresh()

export default function RecordingPill(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="recording-pill"
      class="RecordingPill"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.TOP}
      marginTop={18}
      application={app}
      // Whole window (and its input region) exists only while recording, so it
      // never sits invisibly at top-center swallowing clicks when idle.
      visible={pill((v) => styleOf(v) === "recording")}
    >
      {/* Use the button's OWN reactive label prop, not a child <label>: a child
          label inside a Gtk.Button does not re-render on state change (the timer
          stuck at 0:00), whereas the button's label prop updates reliably. */}
      <button
        class={pill((v) => `recording-pill ${styleOf(v)}`)}
        label={pill((v) => labelOf(v))}
        tooltipText="Click to stop recording"
        onClicked={() => execAsync(["bash", TOGGLE]).catch((e) => print(`stop: ${e}`))}
      />
    </window>
  )
}
