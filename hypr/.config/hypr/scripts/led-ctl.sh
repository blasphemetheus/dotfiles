#!/usr/bin/env bash
# Case/motherboard RGB control via OpenRGB (MSI Mystic Light, 761-byte driver).
# The controller only exposes Direct mode, so everything — including effects —
# is client-driven: plain `openrgb -c RRGGBB` calls against the local SDK server.
#
# State: ~/.local/state/leds/state = "<power> <spec> <brightness>"
#   power:  on|off
#   spec:   RRGGBB hex, RAINBOW (software cycle), or WALLSYNC (match wallpaper)
#   bright: 0-100, applied by scaling the color channels (Direct has no -b)
#
# Subcommands: apply toggle on off set <hex> bright <±N|N> rainbow wallsync
#              wallsync-refresh menu status lock-off _rainbow-loop

STATE_DIR="$HOME/.local/state/leds"
STATE_FILE="$STATE_DIR/state"
RAINBOW_PID="$STATE_DIR/rainbow.pid"
WALL_FILE="$HOME/.cache/current_wallpaper"
WAYBAR_SIGNAL=9

mkdir -p "$STATE_DIR"

read_state() {
    { read -r POWER SPEC BRIGHT < "$STATE_FILE"; } 2>/dev/null || true
    [[ $POWER == on || $POWER == off ]] || POWER=on
    [[ $SPEC =~ ^([0-9A-Fa-f]{6}|RAINBOW|WALLSYNC)$ ]] || SPEC=FF4400
    [[ $BRIGHT =~ ^[0-9]+$ ]] && ((BRIGHT >= 0 && BRIGHT <= 100)) || BRIGHT=100
}

write_state() {
    echo "$POWER $SPEC $BRIGHT" > "$STATE_FILE"
}

set_leds() {  # RRGGBB, already brightness-scaled
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

kill_rainbow() {
    [[ -f $RAINBOW_PID ]] || return 0
    kill "$(cat "$RAINBOW_PID")" 2>/dev/null
    rm -f "$RAINBOW_PID"
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

signal_waybar() {
    pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null
}

apply() {  # reassert current state on the hardware
    read_state
    if [[ $POWER == off ]]; then
        kill_rainbow
        set_leds 000000
    else
        case $SPEC in
            RAINBOW)
                if [[ -f $RAINBOW_PID ]] && kill -0 "$(cat "$RAINBOW_PID")" 2>/dev/null; then
                    :  # already running
                else
                    kill_rainbow
                    "$0" _rainbow-loop & disown
                fi
                ;;
            WALLSYNC)
                kill_rainbow
                set_leds "$(scale_hex "$(wallpaper_color)" "$BRIGHT")"
                ;;
            *)
                kill_rainbow
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
    rainbow)
        read_state
        POWER=on SPEC=RAINBOW
        write_state
        apply
        notify "LEDs: rainbow"
        ;;
    wallsync)
        read_state
        POWER=on SPEC=WALLSYNC
        write_state
        apply
        notify "LEDs: wallpaper sync"
        ;;
    wallsync-refresh)
        # called by wallpaper.sh on every wallpaper change; only act in wallsync mode
        read_state
        [[ $POWER == on && $SPEC == WALLSYNC ]] || exit 0
        set_leds "$(scale_hex "$(wallpaper_color)" "$BRIGHT")"
        ;;
    lock-off)
        # dark while locked, WITHOUT touching saved state (lock-wrapper.sh)
        kill_rainbow
        set_leds 000000
        signal_waybar
        ;;
    menu)
        read_state
        choice=$(printf '%s\n' \
            "󰔡  Toggle (now: $POWER)" \
            "󰸉  Wallpaper sync" \
            "󰑝  Rainbow" \
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
                *)        desc="#$SPEC";;
            esac
            echo "{\"text\":\"󰛨\",\"class\":\"on\",\"tooltip\":\"LEDs: $desc @ ${BRIGHT}%\nClick: off | Right: menu | Scroll: brightness\"}"
        fi
        ;;
    _rainbow-loop)
        echo $$ > "$RAINBOW_PID"
        trap 'exit 0' TERM INT
        hue=0
        while true; do
            read_state
            [[ $POWER == on && $SPEC == RAINBOW ]] || exit 0
            set_leds "$(scale_hex "$(hue_hex $hue)" "$BRIGHT")"
            hue=$(( (hue + 4) % 360 ))
            sleep 0.35
        done
        ;;
    *)
        echo "usage: $0 {apply|toggle|on|off|set RRGGBB|bright N|rainbow|wallsync|menu|status|lock-off}" >&2
        exit 1
        ;;
esac
