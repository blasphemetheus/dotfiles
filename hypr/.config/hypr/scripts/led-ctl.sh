#!/usr/bin/env bash
# Case/motherboard RGB control via OpenRGB (MSI Mystic Light, 761-byte driver).
# The controller only exposes Direct mode, so everything — including effects —
# is client-driven: plain `openrgb -c RRGGBB` calls against the local SDK server.
#
# State: ~/.local/state/leds/state = "<power> <spec> <brightness>"
#   power:  on|off
#   spec:   RRGGBB hex, or an effect: RAINBOW (hue cycle), WALLSYNC (match
#           wallpaper), THERMAL (CPU/GPU temp -> color), BEAT (cava audio
#           pulse), STORM (lightning), FOCUS (color follows focused app),
#           TIMER:<end-epoch>:<total-secs> (countdown)
#   bright: 0-100, applied by scaling the color channels (Direct has no -b)
#
# Effects run as a single background loop (`_effect-loop`, pidfile holds
# "pid spec" so apply() can tell a stale loop from a live matching one).
#
# Subcommands: apply toggle on off set <hex> bright <±N|N> rainbow wallsync
#              thermal beat storm focus timer [min] wallsync-refresh menu
#              status lock-off resume-apply _effect-loop

# No OpenRGB on this machine (laptop): every subcommand is a silent no-op, and
# an empty `status` hides the waybar module.
command -v openrgb >/dev/null 2>&1 || exit 0

STATE_DIR="$HOME/.local/state/leds"
STATE_FILE="$STATE_DIR/state"
EFFECT_PID="$STATE_DIR/effect.pid"
WALL_FILE="$HOME/.cache/current_wallpaper"
WAYBAR_SIGNAL=9

mkdir -p "$STATE_DIR"

read_state() {
    { read -r POWER SPEC BRIGHT < "$STATE_FILE"; } 2>/dev/null || true
    [[ $POWER == on || $POWER == off ]] || POWER=on
    [[ $SPEC =~ ^([0-9A-Fa-f]{6}|RAINBOW|WALLSYNC|THERMAL|BEAT|STORM|FOCUS|TIMER:[0-9]+:[0-9]+)$ ]] || SPEC=FF4400
    [[ $BRIGHT =~ ^[0-9]+$ ]] && ((BRIGHT >= 0 && BRIGHT <= 100)) || BRIGHT=100
}

write_state() {
    echo "$POWER $SPEC $BRIGHT" > "$STATE_FILE"
}

set_leds() {  # RRGGBB, already brightness-scaled
    # NB: each call takes ~1s (CLI waits for device sync; no flag to skip),
    # so every effect loop is paced at roughly 1 color change per second.
    openrgb -c "$1" >/dev/null 2>&1
}

scale_hex() {  # hex pct -> hex
    local hex=${1^^} pct=$2
    printf '%02X%02X%02X' \
        $(( 0x${hex:0:2} * pct / 100 )) \
        $(( 0x${hex:2:2} * pct / 100 )) \
        $(( 0x${hex:4:2} * pct / 100 ))
}

hue_hex() {  # hue 0-359 -> full-saturation hex
    local h=$1 x r g b
    x=$(( h % 60 * 255 / 60 ))
    case $(( h / 60 )) in
        0) r=255       g=$x         b=0;;
        1) r=$((255-x)) g=255       b=0;;
        2) r=0         g=255        b=$x;;
        3) r=0         g=$((255-x)) b=255;;
        4) r=$x        g=0          b=255;;
        *) r=255       g=0          b=$((255-x));;
    esac
    printf '%02X%02X%02X' "$r" "$g" "$b"
}

kill_effect() {
    [[ -f $EFFECT_PID ]] || return 0
    local epid _spec
    { read -r epid _spec < "$EFFECT_PID"; } 2>/dev/null
    [[ -n $epid ]] && kill "$epid" 2>/dev/null
    rm -f "$EFFECT_PID"
}

start_effect() {  # (re)start the loop for the current $SPEC if needed
    local epid espec
    if [[ -f $EFFECT_PID ]]; then
        { read -r epid espec < "$EFFECT_PID"; } 2>/dev/null
        if [[ -n $epid ]] && kill -0 "$epid" 2>/dev/null && [[ $espec == "$SPEC" ]]; then
            return 0  # matching loop already running
        fi
        kill_effect
    fi
    "$0" _effect-loop & disown
}

wallpaper_color() {
    # Dominant vibrant color of the current wallpaper: reduce to a small
    # palette, prefer saturation, then normalize so the max channel is 255
    # (a dark dominant color would otherwise be near-invisible on LEDs).
    local img
    img=$(cat "$WALL_FILE" 2>/dev/null)
    [[ -f $img ]] || { echo FF4400; return; }
    magick "${img}[0]" -resize 64x64^ -colors 6 -unique-colors txt:- 2>/dev/null |
        grep -o '#[0-9A-Fa-f]\{6\}' | tr -d '#' | awk '
        {
            r = strtonum("0x" substr($0,1,2))
            g = strtonum("0x" substr($0,3,2))
            b = strtonum("0x" substr($0,5,2))
            mx = r > g ? r : g; mx = mx > b ? mx : b
            mn = r < g ? r : g; mn = mn < b ? mn : b
            sat = mx - mn
            # prefer saturated colors; among dull ones prefer bright
            score = sat * 1000 + mx
            if (score > best) { best = score; br=r; bg=g; bb=b; bmx=mx }
        }
        END {
            if (bmx == 0) { print "FF4400"; exit }
            printf "%02X%02X%02X\n", br*255/bmx, bg*255/bmx, bb*255/bmx
        }'
}

cpu_gpu_temp() {  # hottest of CPU (k10temp) and GPU, integer °C
    local t=0 h v
    for h in /sys/class/hwmon/hwmon*; do
        [[ $(cat "$h/name" 2>/dev/null) == k10temp ]] || continue
        v=$(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 ))
        (( v > t )) && t=$v
    done
    v=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    [[ $v =~ ^[0-9]+$ ]] && (( v > t )) && t=$v
    echo "$t"
}

focus_color() {  # window class -> RRGGBB; unknown apps get a stable hashed hue
    local c=${1,,}
    case $c in
        "")                    echo 303030;;
        kitty)                 echo FF4400;;
        firefox*|librewolf*|zen*) echo FF7139;;
        code*|cursor*|*zed*)   echo 3B82F6;;
        discord|vesktop|webcord) echo 5865F2;;
        steam*)                echo 1B4B8A;;
        mpv|vlc)               echo 8A2BE2;;
        org.gnome.nautilus|thunar|dolphin) echo 00C2A8;;
        *) hue_hex $(( $(cksum <<<"$c" | cut -d' ' -f1) % 360 ));;
    esac
}

signal_waybar() {
    pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null
}

apply() {  # reassert current state on the hardware
    read_state
    if [[ $POWER == off ]]; then
        kill_effect
        set_leds 000000
    else
        case $SPEC in
            RAINBOW|THERMAL|BEAT|STORM|FOCUS|TIMER:*)
                start_effect
                ;;
            WALLSYNC)
                kill_effect
                set_leds "$(scale_hex "$(wallpaper_color)" "$BRIGHT")"
                ;;
            *)
                kill_effect
                set_leds "$(scale_hex "$SPEC" "$BRIGHT")"
                ;;
        esac
    fi
    signal_waybar
}

notify() {
    notify-send -t 2000 -h string:x-canonical-private-synchronous:leds "RGB" "$1"
}

case "${1:-toggle}" in
    apply)
        apply
        ;;
    toggle)
        read_state
        [[ $POWER == on ]] && POWER=off || POWER=on
        write_state
        apply
        notify "LEDs $POWER"
        ;;
    on|off)
        read_state
        POWER=$1
        write_state
        apply
        notify "LEDs $POWER"
        ;;
    set)
        [[ ${2^^} =~ ^[0-9A-F]{6}$ ]] || { echo "usage: $0 set RRGGBB" >&2; exit 1; }
        read_state
        POWER=on SPEC=${2^^}
        write_state
        apply
        notify "LEDs #$SPEC"
        ;;
    bright)
        read_state
        case $2 in
            +*|-*) BRIGHT=$(( BRIGHT + $2 ));;
            *)     BRIGHT=$2;;
        esac
        (( BRIGHT > 100 )) && BRIGHT=100
        (( BRIGHT < 5 )) && BRIGHT=5
        POWER=on
        write_state
        apply
        notify "LED brightness ${BRIGHT}%"
        ;;
    rainbow|thermal|beat|storm|focus)
        read_state
        POWER=on SPEC=${1^^}
        write_state
        apply
        notify "LEDs: $1"
        ;;
    wallsync)
        read_state
        POWER=on SPEC=WALLSYNC
        write_state
        apply
        notify "LEDs: wallpaper sync"
        ;;
    timer)
        mins=$2
        if [[ ! $mins =~ ^[0-9]+$ ]]; then
            mins=$(printf '%s\n' 5 10 25 45 | wofi --dmenu --prompt "Timer minutes") || exit 0
            [[ $mins =~ ^[0-9]+$ ]] || { echo "timer: need minutes" >&2; exit 1; }
        fi
        (( mins > 0 )) || exit 1
        read_state
        # remember what to go back to when the timer fires (unless we're
        # restarting a timer over a timer)
        [[ $SPEC == TIMER:* ]] || echo "$POWER $SPEC $BRIGHT" > "$STATE_DIR/timer-prev"
        POWER=on SPEC="TIMER:$(( $(date +%s) + mins * 60 )):$(( mins * 60 ))"
        write_state
        apply
        notify "Timer: ${mins}m"
        ;;
    wallsync-refresh)
        # called by wallpaper.sh on every wallpaper change; only act in wallsync mode
        read_state
        [[ $POWER == on && $SPEC == WALLSYNC ]] || exit 0
        set_leds "$(scale_hex "$(wallpaper_color)" "$BRIGHT")"
        ;;
    resume-apply)
        # hypridle after_sleep_cmd. S3 resume resets the Mystic Light USB
        # device in place (same devnum, no udev add event), staling the root
        # SDK server's fd; openrgb-resume.service restarts it. Wait for the
        # SDK port to come back, give detection a moment, then reassert state.
        for _ in $(seq 1 40); do
            (echo >/dev/tcp/127.0.0.1/6742) 2>/dev/null && break
            sleep 0.5
        done
        sleep 2
        apply
        ;;
    lock-off)
        # dark while locked, WITHOUT touching saved state (lock-wrapper.sh)
        kill_effect
        set_leds 000000
        signal_waybar
        ;;
    menu)
        read_state
        choice=$(printf '%s\n' \
            "󰔡  Toggle (now: $POWER)" \
            "󰸉  Wallpaper sync" \
            "󰑝  Rainbow" \
            "󰔏  Thermal glow" \
            "󰐌  Beat pulse" \
            "󰖓  Thunderstorm" \
            "󰖯  Focus accent" \
            "󰔛  Timer" \
            "  Warm white  FFB46B" \
            "  White       FFFFFF" \
            "  Red         FF0000" \
            "  Orange      FF4400" \
            "  Purple      8A2BE2" \
            "  Cyan        00E5FF" \
            "  Green       00FF44" \
            "  Pink        FF2288" \
            "󰃞  Brightness 100%" \
            "󰃟  Brightness 60%" \
            "󰃝  Brightness 30%" \
            "󰃜  Brightness 10%" \
            "󰌾  Off" \
            | wofi --dmenu --prompt "LEDs (or type a hex color)" ) || exit 0
        case $choice in
            *Toggle*)      exec "$0" toggle;;
            *Wallpaper*)   exec "$0" wallsync;;
            *Rainbow*)     exec "$0" rainbow;;
            *Thermal*)     exec "$0" thermal;;
            *Beat*)        exec "$0" beat;;
            *Thunder*)     exec "$0" storm;;
            *Focus*)       exec "$0" focus;;
            *Timer*)       exec "$0" timer;;
            *Brightness*)  exec "$0" bright "$(grep -o '[0-9]\+' <<<"$choice")";;
            *Off*)         exec "$0" off;;
            *)
                hex=$(grep -oE '[0-9A-Fa-f]{6}' <<<"$choice" | tail -1)
                [[ -n $hex ]] && exec "$0" set "$hex"
                ;;
        esac
        ;;
    status)
        # waybar custom module (return-type: json, signal 9)
        read_state
        if [[ $POWER == off ]]; then
            echo '{"text":"󰛩","class":"off","tooltip":"LEDs off\nClick: on | Right: menu"}'
        else
            case $SPEC in
                RAINBOW)  desc="rainbow";;
                WALLSYNC) desc="wallpaper sync";;
                THERMAL)  desc="thermal glow";;
                BEAT)     desc="beat pulse";;
                STORM)    desc="thunderstorm";;
                FOCUS)    desc="focus accent";;
                TIMER:*)  end=${SPEC#TIMER:}; end=${end%%:*}
                          desc="timer $(( (end - $(date +%s) + 59) / 60 ))m";;
                *)        desc="#$SPEC";;
            esac
            echo "{\"text\":\"󰛨\",\"class\":\"on\",\"tooltip\":\"LEDs: $desc @ ${BRIGHT}%\nClick: off | Right: menu | Scroll: brightness\"}"
        fi
        ;;
    _effect-loop)
        read_state
        MYSPEC=$SPEC
        echo "$$ $MYSPEC" > "$EFFECT_PID"
        trap 'exit 0' TERM INT
        # every loop re-reads state each tick and exits when power goes off or
        # the spec changes; long sleeps run as `sleep & wait` so TERM lands
        # immediately instead of after the sleep.
        case $MYSPEC in
            RAINBOW)
                hue=0
                while true; do
                    read_state
                    [[ $POWER == on && $SPEC == RAINBOW ]] || exit 0
                    set_leds "$(scale_hex "$(hue_hex $hue)" "$BRIGHT")"
                    hue=$(( (hue + 4) % 360 ))
                    sleep 0.35
                done
                ;;
            THERMAL)
                # 35°C -> hue 210 (ice blue), 85°C -> hue 0 (red)
                while true; do
                    read_state
                    [[ $POWER == on && $SPEC == THERMAL ]] || exit 0
                    t=$(cpu_gpu_temp)
                    (( t < 35 )) && t=35
                    (( t > 85 )) && t=85
                    set_leds "$(scale_hex "$(hue_hex $(( (85 - t) * 210 / 50 )))" "$BRIGHT")"
                    sleep 2 & wait $!
                done
                ;;
            BEAT)
                conf=$STATE_DIR/cava.conf
                fifo=$STATE_DIR/cava.fifo
                printf '[general]\nbars = 2\nframerate = 15\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\n' > "$conf"
                rm -f "$fifo"; mkfifo "$fifo"
                cava -p "$conf" > "$fifo" 2>/dev/null &
                cavapid=$!
                trap 'kill "$cavapid" 2>/dev/null; rm -f "$fifo"; exit 0' TERM INT
                level=0 lastbucket=-1 n=0
                while IFS=';' read -r b1 b2 _; do
                    # drain queued frames so we always act on the newest one
                    # (each openrgb call takes longer than a 15fps frame)
                    while IFS=';' read -r -t 0.01 x y _; do b1=$x b2=$y; done
                    [[ $b1 =~ ^[0-9]+$ ]] || continue
                    [[ $b2 =~ ^[0-9]+$ ]] || b2=0
                    peak=$(( b1 > b2 ? b1 : b2 ))
                    # fast attack, decay tuned to ~1 iteration/sec (set_leds
                    # latency dominates; queued frames are drained above)
                    (( peak > level )) && level=$peak || level=$(( level > 20 ? level - 20 : 0 ))
                    bucket=$(( level / 20 ))
                    if (( bucket != lastbucket )); then
                        lastbucket=$bucket
                        read_state
                        [[ $POWER == on && $SPEC == BEAT ]] || break
                        set_leds "$(scale_hex FF4400 $(( (level < 10 ? 10 : level) * BRIGHT / 100 )))"
                    elif (( ++n % 60 == 0 )); then
                        read_state
                        [[ $POWER == on && $SPEC == BEAT ]] || break
                    fi
                done < "$fifo"
                kill "$cavapid" 2>/dev/null
                rm -f "$fifo"
                ;;
            STORM)
                while true; do
                    read_state
                    [[ $POWER == on && $SPEC == STORM ]] || exit 0
                    base=$(scale_hex 1A2233 "$BRIGHT")
                    set_leds "$base"
                    sleep $(( RANDOM % 11 + 4 )) & wait $!
                    read_state
                    [[ $POWER == on && $SPEC == STORM ]] || exit 0
                    # set_leds latency (~1s) is the flash duration itself
                    flashes=$(( RANDOM % 2 + 1 ))
                    for (( i = 0; i < flashes; i++ )); do
                        set_leds "$(scale_hex FFFFFF "$BRIGHT")"
                        set_leds "$base"
                    done
                done
                ;;
            FOCUS)
                last=__none__
                while true; do
                    read_state
                    [[ $POWER == on && $SPEC == FOCUS ]] || exit 0
                    class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
                    if [[ $class != "$last" ]]; then
                        last=$class
                        set_leds "$(scale_hex "$(focus_color "$class")" "$BRIGHT")"
                    fi
                    sleep 0.5
                done
                ;;
            TIMER:*)
                end=${MYSPEC#TIMER:}; total=${end#*:}; end=${end%%:*}
                while true; do
                    read_state
                    [[ $POWER == on && $SPEC == "$MYSPEC" ]] || exit 0
                    rem=$(( end - $(date +%s) ))
                    if (( rem <= 0 )); then
                        notify-send -u critical -t 8000 "Timer" "Time's up"
                        for _ in $(seq 1 5); do  # set_leds latency paces this
                            set_leds FF0000
                            set_leds 000000
                        done
                        # restore whatever mode the timer replaced
                        { read -r p s b < "$STATE_DIR/timer-prev"; } 2>/dev/null
                        [[ $p == on || $p == off ]] || { p=on s=FF4400 b=$BRIGHT; }
                        echo "$p $s $b" > "$STATE_FILE"
                        rm -f "$STATE_DIR/timer-prev" "$EFFECT_PID"
                        "$0" apply & disown
                        exit 0
                    fi
                    hue=$(( rem * 130 / total ))
                    (( hue > 130 )) && hue=130
                    set_leds "$(scale_hex "$(hue_hex $hue)" "$BRIGHT")"
                    sleep 1
                done
                ;;
        esac
        ;;
    *)
        echo "usage: $0 {apply|toggle|on|off|set RRGGBB|bright N|rainbow|thermal|beat|storm|focus|timer [min]|wallsync|menu|status|lock-off}" >&2
        exit 1
        ;;
esac
