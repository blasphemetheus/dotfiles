#!/usr/bin/env bash
# Event-driven Claude Code indicator for waybar
# Listens to Hyprland IPC — recomputes on window focus/title changes
# Outputs JSON for waybar with text + tooltip

SOCKET="/run/user/1000/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

get_claude_info() {
    local active title pid
    active=$(hyprctl activewindow 2>/dev/null)
    title=$(echo "$active" | grep '^\s*title:' | sed 's/.*title: //')
    pid=$(echo "$active" | grep '^\s*pid:' | sed 's/.*pid: //')

    if [[ "$title" != *"Claude Code"* ]] || [[ -z "$pid" ]]; then
        echo '{"text": "", "tooltip": "", "class": "inactive"}'
        return
    fi

    # Extract spinner from title (the braille chars ⠁⠂⠄⡀⢀⠠⠐⠈ indicate thinking)
    local spinner=""
    if [[ "$title" =~ ^[⠁⠂⠄⡀⢀⠠⠐⠈✱] ]]; then
        spinner="${title%% *}"
    fi

    # Walk process tree to find claude
    local claude_pid="" queue=($pid) depth=0
    while [[ ${#queue[@]} -gt 0 && $depth -lt 5 ]]; do
        local next_queue=()
        for p in "${queue[@]}"; do
            for child in $(pgrep -P "$p" 2>/dev/null); do
                if [[ "$(cat /proc/$child/comm 2>/dev/null)" == *claude* ]]; then
                    claude_pid="$child"
                    break 3
                fi
                next_queue+=("$child")
            done
        done
        queue=("${next_queue[@]}")
        ((depth++))
    done

    if [[ -z "$claude_pid" ]]; then
        echo '{"text": " Claude Code", "tooltip": "Claude Code (no process found)", "class": "active"}'
        return
    fi

    local cwd project project_key session_dir session_file
    cwd=$(readlink -f "/proc/$claude_pid/cwd" 2>/dev/null)
    project=$(basename "$cwd")

    project_key=$(echo "$cwd" | sed 's|/|-|g; s|^-||')
    session_dir="$HOME/.claude/projects/-${project_key}"
    session_file=$(ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1)

    local slug="" branch="" model="" start_time="" duration=""
    local input_tok=0 output_tok=0 cache_create=0 cache_read=0

    if [[ -n "$session_file" ]]; then
        slug=$(grep -oP '"slug":"[^"]*"' "$session_file" 2>/dev/null | tail -1 | sed 's/"slug":"//;s/"//')
        branch=$(grep -oP '"gitBranch":"[^"]*"' "$session_file" 2>/dev/null | head -1 | sed 's/"gitBranch":"//;s/"//')
        model=$(grep -oP '"model":"[^"]*"' "$session_file" 2>/dev/null | head -1 | sed 's/"model":"//;s/"//')
        start_time=$(head -1 "$session_file" | grep -oP '"timestamp":"[^"]*"' | head -1 | sed 's/"timestamp":"//;s/"//')

        # Sum tokens
        local token_data
        token_data=$(grep -oP '"(input_tokens|output_tokens|cache_creation_input_tokens|cache_read_input_tokens)":\d+' "$session_file" 2>/dev/null)
        input_tok=$(echo "$token_data" | grep '"input_tokens"' | awk -F: '{s+=$2} END {print s+0}')
        output_tok=$(echo "$token_data" | grep '"output_tokens"' | awk -F: '{s+=$2} END {print s+0}')
        cache_create=$(echo "$token_data" | grep '"cache_creation_input_tokens"' | awk -F: '{s+=$2} END {print s+0}')
        cache_read=$(echo "$token_data" | grep '"cache_read_input_tokens"' | awk -F: '{s+=$2} END {print s+0}')
    fi

    # Calculate session duration
    if [[ -n "$start_time" ]]; then
        local start_epoch now_epoch diff_s hours mins
        start_epoch=$(date -d "$start_time" +%s 2>/dev/null)
        now_epoch=$(date +%s)
        diff_s=$((now_epoch - start_epoch))
        hours=$((diff_s / 3600))
        mins=$(( (diff_s % 3600) / 60 ))
        if [[ $hours -gt 0 ]]; then
            duration="${hours}h ${mins}m"
        else
            duration="${mins}m"
        fi
    fi

    # Estimate cost (Opus 4.6 pricing: $15/M input, $75/M output, $3.75/M cache read, $18.75/M cache write)
    local cost
    cost=$(awk "BEGIN {
        inp = $input_tok * 15 / 1000000
        out = $output_tok * 75 / 1000000
        cr  = $cache_read * 3.75 / 1000000
        cw  = $cache_create * 18.75 / 1000000
        printf \"%.2f\", inp + out + cr + cw
    }")

    # Format token counts (K)
    local in_k out_k
    in_k=$(awk "BEGIN {printf \"%.1f\", $input_tok / 1000}")
    out_k=$(awk "BEGIN {printf \"%.1f\", $output_tok / 1000}")

    # Determine status from spinner
    local status="idle"
    local status_icon="✦"
    if [[ "$spinner" == "✱" ]]; then
        status="idle"
        status_icon="✦"
    elif [[ -n "$spinner" ]]; then
        status="thinking"
        status_icon="$spinner"
    fi

    # Short model name
    local model_short
    case "$model" in
        claude-opus-4-6)    model_short="opus" ;;
        claude-sonnet-4-6)  model_short="sonnet" ;;
        claude-haiku-4-5*)  model_short="haiku" ;;
        *)                  model_short="$model" ;;
    esac

    # Bar text: spinner + session (project) | duration
    local bar_text="$status_icon Claude: ${slug:-$project} ($project) | ${duration:-0m}"

    # Tooltip: full details
    local tooltip=""
    tooltip+="Session: ${slug:-unknown}\\n"
    tooltip+="Model: ${model_short:-unknown}\\n"
    tooltip+="Branch: ${branch:-unknown}\\n"
    tooltip+="Duration: ${duration:-unknown}\\n"
    tooltip+="─────────────────\\n"
    tooltip+="Input: ${in_k}K tokens\\n"
    tooltip+="Output: ${out_k}K tokens\\n"
    tooltip+="Cost: \$${cost}"

    # Escape for JSON
    bar_text=$(echo "$bar_text" | sed 's/"/\\"/g')
    tooltip=$(echo "$tooltip" | sed 's/"/\\"/g')

    echo "{\"text\": \"$bar_text\", \"tooltip\": \"$tooltip\", \"class\": \"$status\"}"
}

# Print initial state
get_claude_info

# Listen for focus/title changes
socat -u "UNIX-CONNECT:$SOCKET" STDOUT 2>/dev/null | while read -r line; do
    case "$line" in
        activewindow\>\>*|windowtitle\>\>*)
            get_claude_info
            ;;
    esac
done
