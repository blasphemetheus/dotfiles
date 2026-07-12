import { Astal, Gdk } from "astal/gtk3"
import { Variable } from "astal"
import GLib from "gi://GLib"

// Dictation state pill — floats bottom-center while hyprwhspr-rs is hot.
// State/label logic lives in scripts/dictation-pill.sh ("<style>|<label>"):
// listening (with recording timer), transcribing, done (flashes the inserted
// text), error, hidden. Click-through so it never steals input.
//
// NOTE: written for AGS v2 / astal imports (what nixpkgs ships). The rest of
// this config (Dashboard.tsx) is AGS v3 style and needs a flake input to run.

const HOME = GLib.get_home_dir()

const state = Variable("hidden|").poll(250, [
  "bash",
  `${HOME}/.config/ags/scripts/dictation-pill.sh`,
])

const styleOf = (v: string) => v.slice(0, v.indexOf("|"))
const labelOf = (v: string) => v.slice(v.indexOf("|") + 1)

export default function DictationPill(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="dictation-pill"
      className="DictationPill"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.BOTTOM}
      marginBottom={18}
      clickThrough={true}
      visible={true}
    >
      <box className={state((v) => `dictation-pill ${styleOf(v)}`)}>
        <label label={state((v) => labelOf(v))} />
      </box>
    </window>
  )
}
