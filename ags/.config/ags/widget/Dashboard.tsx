import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"

// Command center for nixos_slanka. Toggle with Super+D (`ags toggle dashboard`).
// Rebuilt 2026-07 from the inherited config (which was never functional here
// and still pointed at /home/dori): these widgets are about THIS machine —
// VRAM pressure from the BEAM workloads, dictation state, disk pressure on
// the shared / + /nix partition, dotfiles health.

const HOME = GLib.get_home_dir()

// ── System ──────────────────────────────────────────────────────────
const uptime = createPoll("...", 30000, "uptime -p | sed 's/up //'")

const diskRoot = createPoll("...", 30000, `bash -c "df -h / | awk 'NR==2 {print \\$3\\" / \\"\\$2\\"  (\\"\\$5\\")\\"}'"`)
const diskData = createPoll("...", 30000, `bash -c "df -h /data 2>/dev/null | awk 'NR==2 {print \\$3\\" / \\"\\$2\\"  (\\"\\$5\\")\\"}' || echo 'not mounted'"`)

const ram = createPoll("...", 5000, `bash -c "free -h | awk '/^Mem/ {print \\$3\\" / \\"\\$2}'"`)

// VRAM + the current biggest hog. The BEAM workloads routinely hold ~29GB of
// the 5090 — this answers "can a GPU job even fit right now?" at a glance.
const vram = createPoll("...", 5000, `bash -c "nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{printf \\"%.1f / %.1f GB\\", \\$1/1024, \\$2/1024}'"`)
const vramHog = createPoll("", 10000, `bash -c "nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader,nounits 2>/dev/null | sort -t, -k2 -rn | head -1 | awk -F', ' '{n=\\$1; sub(/.*\\\\//,\\"\\",n); printf \\"%s: %.1f GB\\", n, \\$2/1024}'"`)

// ── Dictation ───────────────────────────────────────────────────────
const RUNTIME = GLib.get_user_runtime_dir()
const dictationState = createPoll("...", 2000, `bash -c "jq -r '.tooltip // \\"unknown\\"' ~/.cache/hyprwhspr-rs/status.json 2>/dev/null"`)
const lastDictation = createPoll("—", 5000, `bash -c "cat ${RUNTIME}/dictation-pill/flash_text 2>/dev/null | head -c 60 || echo '—'"`)

// ── Dotfiles health (the weekly notifier's essentials, always visible) ──
const flakeAge = createPoll("...", 3600000, `bash -c "echo \\$(( ( \\$(date +%s) - \\$(stat -c %Y ${HOME}/dotfiles/flake.lock) ) / 86400 ))' days'"`)
const gitDirty = createPoll("...", 60000, `bash -c "cd ${HOME}/dotfiles && n=\\$(git status --porcelain | wc -l); u=\\$(git log origin/main..main --oneline 2>/dev/null | wc -l); echo \\"\\$n dirty, \\$u unpushed\\""`)

// ── Weather (kept from the old dashboard — it earned its spot) ─────
const weather = createPoll("Loading...", 900000, `bash -c "curl -s --max-time 10 'wttr.in/?format=%t+%C' 2>/dev/null || echo 'unavailable'"`)

function Row({ label, value }: { label: string; value: any }) {
  return (
    <box class="info-row" homogeneous>
      <label class="info-label" label={label} halign={Gtk.Align.START} />
      <label class="info-value" label={value} halign={Gtk.Align.END} />
    </box>
  )
}

function Section({ title, children }: { title: string; children?: any }) {
  return (
    <box vertical class="section">
      <label class="section-title" label={title} halign={Gtk.Align.START} />
      {children}
    </box>
  )
}

function ActionButton({ label, cmd }: { label: string; cmd: string }) {
  return (
    <button
      class="utility-btn"
      label={label}
      onClicked={() => execAsync(cmd).catch((e) => print(`${label}: ${e}`))}
    />
  )
}

export default function Dashboard(gdkmonitor: Gdk.Monitor) {
  const { TOP, RIGHT, BOTTOM } = Astal.WindowAnchor

  return (
    <window
      name="dashboard"
      class="Dashboard"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT | BOTTOM}
      application={app}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
    >
      <scrollable hscroll={Gtk.PolicyType.NEVER} vscroll={Gtk.PolicyType.AUTOMATIC} css="min-width: 380px;">
        <box vertical class="dashboard-content">
          <label class="dashboard-title" label="slanka" />

          <Section title="System">
            <Row label="Uptime" value={uptime} />
            <Row label="RAM" value={ram} />
            <Row label="/ (with /nix)" value={diskRoot} />
            <Row label="/data" value={diskData} />
          </Section>

          <Section title="GPU — RTX 5090">
            <Row label="VRAM" value={vram} />
            <Row label="Top hog" value={vramHog} />
          </Section>

          <Section title="Dictation  (F12 · hold Super+Space)">
            <Row label="State" value={dictationState} />
            <Row label="Last" value={lastDictation} />
          </Section>

          <Section title="Dotfiles">
            <Row label="flake.lock age" value={flakeAge} />
            <Row label="git" value={gitDirty} />
          </Section>

          <Section title="Weather">
            <label label={weather} halign={Gtk.Align.START} />
          </Section>

          <Section title="Quick actions">
            <box class="utilities-row" homogeneous>
              <ActionButton label="🔢 Calc" cmd={`${HOME}/.config/ags/scripts/calculator.sh`} />
              <ActionButton label="😀 Emoji" cmd={`${HOME}/.config/ags/scripts/emoji.sh`} />
              <ActionButton label="🔍 Zoom" cmd={`${HOME}/.config/ags/scripts/zoom-toggle.sh`} />
            </box>
            <box class="utilities-row" homogeneous>
              <ActionButton label="⏺ Record" cmd={`${HOME}/.config/ags/scripts/screen-record-toggle.sh`} />
              <ActionButton label="🎮 rwing" cmd="rwing" />
              <ActionButton label="☕ Caffeine" cmd={`${HOME}/.config/ags/scripts/caffeine-toggle.sh`} />
            </box>
          </Section>
        </box>
      </scrollable>
    </window>
  )
}
