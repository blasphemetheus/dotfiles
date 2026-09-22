import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { createState } from "ags"
import { monitorFile } from "ags/file"
import { interval, Timer } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

// Voice command pill — floats bottom-center while voice-command.sh is hot
// (Super+U router: listening → transcribing → thinking → done/error).
// State/label logic lives in scripts/command-pill.sh ("<style>|<label>"):
// listening (with recording timer), transcribing, thinking (ollama round-trip),
// done/error (3s flash), hidden. Click-through so it never steals input.
//
// Cloned from DictationPill.tsx — same createPoll-leak rationale applies
// (a fixed poll leaked the gjs heap to ~50GB over multi-day uptime): react to
// the state file via monitorFile (near-zero idle cost), 1s ticker only while
// the listening timer animates. Sits 64px up so both pills can show at once.

const RUNTIME = GLib.get_user_runtime_dir()
const SCRIPT = `${GLib.get_home_dir()}/.config/ags/scripts/command-pill.sh`
const STATE = `${RUNTIME}/voice-command/state`

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
      // listening → timer ticks up. Everything else (transcribing, thinking,
      // done, error, hidden) is static or self-expiring: rest on the monitor.
      setTicker(styleOf(v) === "listening")
    })
    .catch(() => {
      setPill("hidden|")
      setTicker(false)
    })
}

// React to every state transition voice-command.sh writes; render now.
monitorFile(STATE, () => refresh())
refresh()

export default function CommandPill(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="command-pill"
      class="CommandPill"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.BOTTOM}
      marginBottom={64}
      application={app}
      visible={true}
    >
      <box class={pill((v) => `command-pill ${styleOf(v)}`)}>
        <label label={pill((v) => labelOf(v))} />
      </box>
    </window>
  )
}
