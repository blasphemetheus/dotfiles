# Persistent Mako history, notification picker, and the opt-in DND digest.
{
  config,
  pkgs,
  ...
}:
let
  # Persistent notification history: mako's own history is in-memory (lost on
  # mako restart / logout), so log every Notify DBus call to a jsonl file. jq
  # --arg does the JSON escaping, so bodies with quotes/commas stay valid.
  notifLogger = pkgs.writeShellApplication {
    name = "notification-logger";
    runtimeInputs = with pkgs; [
      dbus
      jq
      coreutils
    ];
    text = ''
      logfile="${config.home.homeDirectory}/.local/state/mako/history.jsonl"
      mkdir -p "$(dirname "$logfile")"
      dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null |
      while IFS= read -r line; do
        case "$line" in
          *"member=Notify"*) inblock=1; sc=0; app=""; sum=""; body="" ;;
          "   string "*)
            if [ "''${inblock:-0}" = 1 ]; then
              sc=$((sc + 1)); s=''${line#*\"}; s=''${s%\"}
              case $sc in 1) app=$s ;; 3) sum=$s ;; 4) body=$s ;; esac
            fi ;;
          "   array ["*)
            if [ "''${inblock:-0}" = 1 ] && [ "$sc" -ge 4 ]; then
              jq -nc --arg a "$app" --arg s "$sum" --arg b "$body" --argjson t "$(date +%s)" \
                '{time:$t,app:$a,summary:$s,body:$b}' >> "$logfile" 2>/dev/null || true
              inblock=0
            fi ;;
        esac
      done
    '';
  };

  # Rofi picker over the persistent log (Super+Shift+N): search all history,
  # pick one, re-display it. Trims the log to the last 5000 lines on open.
  notifPicker = pkgs.writeShellApplication {
    name = "notification-picker";
    runtimeInputs = with pkgs; [
      jq
      rofi
      libnotify
      coreutils
    ];
    text = ''
      logfile="${config.home.homeDirectory}/.local/state/mako/history.jsonl"
      if [ ! -s "$logfile" ]; then notify-send "Notification history" "empty so far"; exit 0; fi
      tail -n 5000 "$logfile" > "$logfile.tmp" && mv "$logfile.tmp" "$logfile"
      mapfile -t entries < <(tac "$logfile")
      display=$(printf '%s\n' "''${entries[@]}" | jq -r \
        '[(.time|strflocaltime("%m-%d %H:%M")), "[\(.app)]", .summary, (if .body!="" then "— "+.body else "" end)] | join(" ") | gsub("\n";" ")')
      idx=$(printf '%s\n' "$display" | rofi -dmenu -i -p "Notifications" -format 'i')
      [ -n "$idx" ] || exit 0
      entry="''${entries[$idx]}"
      notify-send -a "$(jq -r .app <<<"$entry")" "$(jq -r .summary <<<"$entry")" "$(jq -r .body <<<"$entry")"
    '';
  };
in
{
  # Persistent notification logger. WantedBy=default.target, NOT
  # graphical-session.target — the latter doesn't activate under greetd.
  systemd.user.services.notification-logger = {
    Unit = {
      Description = "Persistent notification history logger";
      After = [ "dbus.service" ];
    };
    Service = {
      ExecStart = "${notifLogger}/bin/notification-logger";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Hourly LLM notification digest, running ONLY while DND is on: the timer
  # deliberately has no Install.WantedBy — dnd-smart.sh starts/stops it with
  # the mako mode, so DND state is the only owner and there's no enable-state
  # to drift across reboots.
  systemd.user.services.notif-digest = {
    Unit.Description = "LLM notification digest (mako history → ollama summary)";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/hypr/scripts/notif-digest.sh";
    };
  };
  systemd.user.timers.notif-digest = {
    Unit.Description = "Hourly notification digest while DND is active";
    Timer = {
      OnCalendar = "hourly";
      Persistent = false;
    };
    # NO Install.WantedBy — dnd-smart.sh owns this timer's lifecycle.
  };

  # notification-picker on PATH for the Hyprland keybinding.
  home.packages = [ notifPicker ];
}
