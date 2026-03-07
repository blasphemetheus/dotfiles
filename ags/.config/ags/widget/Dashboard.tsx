import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { execAsync, exec } from "ags/process"
import { createPoll } from "ags/time"

// ============ POLLED DATA ============

const uptime = createPoll("...", 30000, "uptime -p | sed 's/up //'")
const processCount = createPoll("...", 5000, "ps aux | wc -l")
const sshSessions = createPoll("0", 10000, "bash -c \"who | grep -c pts 2>/dev/null || echo 0\"")
const publicIP = createPoll("...", 300000, "bash -c \"curl -s --max-time 5 ifconfig.me || echo 'offline'\"")
const hotspotStatus = createPoll("OFF", 10000, "bash -c \"nmcli -t -f NAME con show --active 2>/dev/null | grep -qi hotspot && echo ON || echo OFF\"")
const portWatchers = createPoll("None", 15000, "bash -c \"ss -tlnp 2>/dev/null | grep LISTEN | awk '{print \\$4}' | grep -oE '[0-9]+\\$' | sort -nu | head -8 | tr '\\n' ' ' || echo None\"")
const batteryHealth = createPoll("...", 60000, `bash -c "
  if [ -f /sys/class/power_supply/BAT0/cycle_count ]; then
    cycles=\\$(cat /sys/class/power_supply/BAT0/cycle_count 2>/dev/null || echo 0)
    full=\\$(cat /sys/class/power_supply/BAT0/charge_full 2>/dev/null || cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo 1)
    design=\\$(cat /sys/class/power_supply/BAT0/charge_full_design 2>/dev/null || cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null || echo 1)
    health=\\$((full * 100 / design))
    echo \\"Cycles: \\$cycles | Health: \\$health%\\"
  else
    echo 'N/A'
  fi
"`)
const vramUsage = createPoll("N/A", 5000, `bash -c "
  if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{printf \\"%.1fGB / %.1fGB\\", \\$1/1024, \\$2/1024}'
  elif [ -f /sys/class/drm/card0/device/mem_info_vram_used ]; then
    used=\\$(cat /sys/class/drm/card0/device/mem_info_vram_used)
    total=\\$(cat /sys/class/drm/card0/device/mem_info_vram_total)
    echo \\"\\$((used/1024/1024))MB / \\$((total/1024/1024))MB\\"
  else
    echo 'N/A'
  fi
"`)
const weatherData = createPoll("Loading...", 900000, `bash -c "
  data=\\$(curl -s --max-time 10 'wttr.in/?format=%t+%C+|+UV:%u+|+Humidity:%h' 2>/dev/null)
  if [ -n \\"\\$data\\" ]; then echo \\"\\$data\\"; else echo 'Weather unavailable'; fi
"`)
const sunTimes = createPoll("", 3600000, `bash -c "
  data=\\$(curl -s --max-time 10 'wttr.in/?format=Rise:%S+Set:%s' 2>/dev/null)
  if [ -n \\"\\$data\\" ]; then echo \\"\\$data\\"; else echo 'N/A'; fi
"`)
const screenRecording = createPoll("⚫ Not Recording", 1000, "/home/dori/.config/ags/scripts/screen-record-status.sh")
const caffeineLabel = createPoll("😴 Caffeine OFF", 1000, "/home/dori/.config/ags/scripts/caffeine-status.sh")

// Debug: simple time poll to verify polls work
const debugTime = createPoll("--:--:--", 1000, "date +%H:%M:%S")

// Word of the day (static per day)
const spanishWords = [
  { word: "mariposa", meaning: "butterfly" },
  { word: "esperanza", meaning: "hope" },
  { word: "estrella", meaning: "star" },
  { word: "corazón", meaning: "heart" },
  { word: "amanecer", meaning: "dawn" },
  { word: "lluvia", meaning: "rain" },
  { word: "montaña", meaning: "mountain" },
]
const chineseWords = [
  { word: "快乐", pinyin: "kuàilè", meaning: "happy" },
  { word: "朋友", pinyin: "péngyou", meaning: "friend" },
  { word: "学习", pinyin: "xuéxí", meaning: "to study" },
  { word: "美丽", pinyin: "měilì", meaning: "beautiful" },
  { word: "时间", pinyin: "shíjiān", meaning: "time" },
  { word: "天空", pinyin: "tiānkōng", meaning: "sky" },
  { word: "音乐", pinyin: "yīnyuè", meaning: "music" },
]
const todayIndex = new Date().getDate() % spanishWords.length
const spanishWord = spanishWords[todayIndex]
const chineseWord = chineseWords[todayIndex]

// Stopwatch state
let stopwatchSeconds = 0
let stopwatchRunning = false

function formatTime(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`
}

function toggleStopwatch() {
  stopwatchRunning = !stopwatchRunning
}

function resetStopwatch() {
  stopwatchRunning = false
  stopwatchSeconds = 0
}

// ============ WIDGET COMPONENTS ============

function SectionTitle({ title }: { title: string }) {
  return <label class="section-title" label={title} halign={Gtk.Align.START} />
}

function InfoRow({ label, value }: { label: string; value: any }) {
  return (
    <box class="info-row">
      <label class="info-label" label={label} halign={Gtk.Align.START} hexpand />
      <label class="info-value" label={value} />
    </box>
  )
}

function SystemSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="System" />
      <InfoRow label="Uptime:" value={uptime} />
      <InfoRow label="Processes:" value={processCount} />
      <InfoRow label="SSH Sessions:" value={sshSessions} />
      <InfoRow label="Public IP:" value={publicIP} />
      <InfoRow label="Hotspot:" value={hotspotStatus} />
      <InfoRow label="Battery:" value={batteryHealth} />
      <InfoRow label="VRAM:" value={vramUsage} />
    </box>
  )
}

function PortsSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Listening Ports" />
      <label class="ports-list" label={portWatchers} halign={Gtk.Align.START} wrap />
    </box>
  )
}

function WeatherSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Weather" />
      <label class="weather-main" label={weatherData} halign={Gtk.Align.START} wrap />
      <label label={sunTimes} halign={Gtk.Align.START} />
    </box>
  )
}

function StopwatchSection() {
  const stopwatchDisplay = createPoll("00:00:00", 1000, () => {
    if (stopwatchRunning) stopwatchSeconds++
    return formatTime(stopwatchSeconds)
  })

  return (
    <box vertical class="section">
      <SectionTitle title="Stopwatch" />
      <label class="stopwatch-display" label={stopwatchDisplay} />
      <box class="stopwatch-buttons" homogeneous>
        <button class="stopwatch-btn" label="Start/Stop" onClicked={toggleStopwatch} />
        <button class="stopwatch-btn" label="Reset" onClicked={resetStopwatch} />
      </box>
    </box>
  )
}

function TogglesSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Toggles" />
      <box class="toggles-row" homogeneous>
        <button
          class="toggle-btn"
          onClicked={() => {
            execAsync("/home/dori/.config/ags/scripts/caffeine-toggle.sh").catch((e) => print(`Caffeine error: ${e}`))
          }}
        >
          <label label={caffeineLabel} />
        </button>
        <button
          class="toggle-btn"
          onClicked={() => {
            execAsync("/home/dori/.config/ags/scripts/screen-record-toggle.sh").catch((e) => print(`Recording error: ${e}`))
          }}
        >
          <label label={screenRecording} />
        </button>
      </box>
    </box>
  )
}

function UtilitiesSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Utilities" />
      <box class="utilities-row" homogeneous>
        <button
          class="utility-btn"
          label="🔢 Calc"
          onClicked={() => execAsync("/home/dori/.config/ags/scripts/calculator.sh").catch((e) => print(`Calc error: ${e}`))}
        />
        <button
          class="utility-btn"
          label="😀 Emoji"
          onClicked={() => execAsync("/home/dori/.config/ags/scripts/emoji.sh").catch((e) => print(`Emoji error: ${e}`))}
        />
        <button
          class="utility-btn"
          label="🔍 Zoom"
          onClicked={() => execAsync("/home/dori/.config/ags/scripts/zoom-toggle.sh").catch((e) => print(`Zoom error: ${e}`))}
        />
      </box>
    </box>
  )
}

function WordOfDaySection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Word of the Day" />
      <box vertical class="word-content">
        <label class="word-lang" label="🇪🇸 Spanish" halign={Gtk.Align.START} />
        <label class="word-entry" label={`${spanishWord.word} - ${spanishWord.meaning}`} halign={Gtk.Align.START} />
        <label class="word-lang" label="🇨🇳 Chinese" halign={Gtk.Align.START} />
        <label class="word-entry" label={`${chineseWord.word} (${chineseWord.pinyin}) - ${chineseWord.meaning}`} halign={Gtk.Align.START} />
      </box>
    </box>
  )
}

function DiscordSection() {
  return (
    <box vertical class="section">
      <SectionTitle title="Discord" />
      <button
        class="utility-btn"
        label="Open Discord"
        onClicked={() => execAsync("discord || vesktop").catch(() => {})}
      />
    </box>
  )
}

// ============ MAIN DASHBOARD ============

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
      <scrollable
        hscroll={Gtk.PolicyType.NEVER}
        vscroll={Gtk.PolicyType.AUTOMATIC}
        css="min-width: 380px;"
      >
        <box vertical class="dashboard-content">
          <label class="dashboard-title" label="Dashboard" />
          <label label={debugTime} />
          <SystemSection />
          <PortsSection />
          <WeatherSection />
          <StopwatchSection />
          <TogglesSection />
          <UtilitiesSection />
          <WordOfDaySection />
          <DiscordSection />
        </box>
      </scrollable>
    </window>
  )
}
