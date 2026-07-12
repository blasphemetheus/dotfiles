import { Astal, Gdk } from "astal/gtk3"
import { Variable } from "astal"

// Dictation state pill — floats bottom-center while hyprwhspr-rs is hot.
// Reads the daemon's status.json (same file waybar uses); click-through so
// it never steals input. Hidden via opacity when idle (see style.scss).
//
// NOTE: written for AGS v2 / astal imports (what nixpkgs ships). The rest of
// this config (Dashboard.tsx) is AGS v3 style and needs a flake input to run.

const state = Variable("hidden|").poll(250, [
  "bash",
  "-c",
  `case "$(jq -r .class "$HOME/.cache/hyprwhspr-rs/status.json" 2>/dev/null)" in
    active) echo "listening|●  Listening…";;
    processing) echo "transcribing|◌  Transcribing…";;
    error) echo "error|✕  Dictation error";;
    *) echo "hidden|";;
  esac`,
])

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
      <box className={state((v) => `dictation-pill ${v.split("|")[0]}`)}>
        <label label={state((v) => v.split("|")[1] ?? "")} />
      </box>
    </window>
  )
}
