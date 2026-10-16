#!/usr/bin/env bash
# Records niri IPC fixtures for unit tests. Run by a human inside a live niri session:
#   nix develop -c scripts/port/record-niri-fixtures.sh <scenario> [seconds]
# Scenarios: idle, fullscreen, kb-switch, multi-monitor, overview.
# Writes tests/fixtures/niri/<scenario>/{version,outputs,workspaces,windows,focused-window,keyboard-layouts}.json
# and event-stream.jsonl (event stream for <seconds>, default 30).
set -euo pipefail

root="${PORT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
scenario="${1:-}"
secs="${2:-30}"

hints() {
    case "$1" in
        idle) echo "Do nothing; just let it record." ;;
        fullscreen) echo "Within the window: put a window into fullscreen (fullscreen-window), then back." ;;
        kb-switch) echo "Within the window: switch keyboard layout several times (niri msg action switch-layout next)." ;;
        multi-monitor) echo "Within the window: focus the other monitor, switch workspaces there, (un)plug if possible." ;;
        overview) echo "Within the window: open and close the overview (toggle-overview)." ;;
        *) return 1 ;;
    esac
}

if [[ -z "$scenario" ]] || ! hints "$scenario" > /dev/null; then
    echo "usage: $0 {idle|fullscreen|kb-switch|multi-monitor|overview} [seconds]" >&2
    exit 2
fi
if [[ -z "${NIRI_SOCKET:-}" ]]; then
    echo "NIRI_SOCKET is not set — run this inside a niri session" >&2
    exit 1
fi
command -v niri > /dev/null || { echo "niri not in PATH (use nix develop)" >&2; exit 1; }
command -v jq > /dev/null || { echo "jq not in PATH (use nix develop)" >&2; exit 1; }

out="$root/tests/fixtures/niri/$scenario"
mkdir -p "$out"

snapshot() {
    local suffix="$1" q
    for q in version outputs workspaces windows focused-window keyboard-layouts; do
        niri msg --json "$q" | jq . > "$out/$q$suffix.json"
    done
}

snapshot ""
echo "Recording '$scenario' for ${secs}s. $(hints "$scenario")"
timeout "$secs" niri msg --json event-stream > "$out/event-stream.jsonl" || [[ $? -eq 124 ]]
snapshot ".after"

{
    echo "scenario: $scenario"
    echo "recorded: $(date -Iseconds)"
    echo "niri: $(niri --version)"
    echo "duration: ${secs}s"
} > "$out/README.txt"

echo "Done: $out ($(wc -l < "$out/event-stream.jsonl") events)"
echo "Event types: $(jq -r 'keys[0]' "$out/event-stream.jsonl" | sort | uniq -c | sort -rn | tr '\n' ' ')"
