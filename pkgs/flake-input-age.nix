{ pkgs }:
pkgs.writeShellApplication {
  name = "flake-input-age";
  runtimeInputs = [
    pkgs.jq
    pkgs.coreutils
  ];
  text = ''
    json=false
    if [[ "''${1:-}" == --json ]]; then json=true; shift; fi
    if [[ $# -gt 1 ]]; then
      echo "Usage: flake-input-age [--json] [flake.lock]" >&2
      exit 2
    fi
    report=$(jq --argjson now "$(date +%s)" -f ${../scripts/flake-input-age.jq} "''${1:-flake.lock}")
    if "$json"; then
      printf '%s\n' "$report"
    else
      jq -r '.[] | "\(.input): " + (if .ageDays == null then "revision age unknown"
        else "\(.ageDays)d (locked source \(.lastModified | strftime("%Y-%m-%d")))" end)' <<< "$report"
    fi
  '';
}
