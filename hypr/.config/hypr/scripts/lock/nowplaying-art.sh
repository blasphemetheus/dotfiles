#!/usr/bin/env bash
# Album art path for the hyprlock image widget (reload_cmd). Local file:// art
# is copied into place; anything else (https, none) yields the transparent
# placeholder so the widget effectively hides. Prints the path to use.
set -u
art="$HOME/.cache/lock-art.png"
blank="$HOME/.cache/lock-art-blank.png"
[[ -s $blank ]] || base64 -d > "$blank" <<'B64'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
B64
url=$(playerctl metadata mpris:artUrl 2>/dev/null)
if [[ $url == file://* ]]; then
    src=${url#file://}
    src=$(printf '%b' "${src//%/\\x}")   # url-decode
    if [[ -r $src ]] && ! cmp -s "$src" "$art"; then cp -f "$src" "$art"; fi
    [[ -s $art ]] && { echo "$art"; exit 0; }
fi
echo "$blank"
