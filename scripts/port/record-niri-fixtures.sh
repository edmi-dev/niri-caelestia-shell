#!/usr/bin/env bash
# Records niri IPC fixtures in an ISOLATED nested session: headless sway (pixman) -> niri (winit) with
# tests/fixtures/niri/config.kdl. Never connects to the user's niri session.
#
#   nix develop -c scripts/port/record-niri-fixtures.sh [scenario ...]     (default: all)
#
# Each scenario gets a fresh niri and writes tests/fixtures/niri/<scenario>/:
#   {version,outputs,workspaces,windows,focused-window,keyboard-layouts}.json   snapshot before
#   event-stream.jsonl                                                          events during the actions
#   *.after.json                                                                snapshot after
#   README.txt                                                                  niri --version, actions
# Limitation: niri's winit backend has exactly one output, so multi-output scenarios can't be recorded here.
set -euo pipefail

root="${PORT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
config="$root/tests/fixtures/niri/config.kdl"
all=(idle windows workspaces fullscreen kb-switch overview config-reload)

for tool in sway niri foot jq; do
    command -v "$tool" > /dev/null || { echo "$tool not in PATH (use nix develop)" >&2; exit 1; }
done

scenarios=("$@")
((${#scenarios[@]})) || scenarios=("${all[@]}")
for s in "${scenarios[@]}"; do
    [[ " ${all[*]} " == *" $s "* ]] || { echo "unknown scenario '$s' (known: ${all[*]})" >&2; exit 2; }
done

# Isolation: private runtime dir, no inherited compositor/session handles
XDG_RUNTIME_DIR="$(mktemp -d)"
export XDG_RUNTIME_DIR
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY NIRI_SOCKET DISPLAY SWAYSOCK DBUS_SESSION_BUS_ADDRESS
logs="$XDG_RUNTIME_DIR/logs"
mkdir -p "$logs"

pids=()
cleanup() {
    local p
    for p in "${pids[@]}"; do kill "$p" 2> /dev/null || true; done
    wait 2> /dev/null || true
    rm -rf "$XDG_RUNTIME_DIR"
}
trap cleanup EXIT

wait_for() { # <tries of 0.1s> <command...>
    local n="$1"
    shift
    for ((i = 0; i < n; i++)); do
        "$@" > /dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "timeout waiting for: $*" >&2
    return 1
}

WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    sway -c /dev/null > "$logs/sway.log" 2>&1 &
pids+=($!)
wait_for 100 test -S "$XDG_RUNTIME_DIR/wayland-1"

niri_pid=""
niri_display=""
start_niri() {
    rm -f "$XDG_RUNTIME_DIR"/niri.*.sock
    WAYLAND_DISPLAY=wayland-1 LIBGL_ALWAYS_SOFTWARE=1 niri -c "$config" > "$logs/niri-$1.log" 2>&1 &
    niri_pid=$!
    pids+=("$niri_pid")
    wait_for 200 compgen -G "$XDG_RUNTIME_DIR/niri.*.sock"
    NIRI_SOCKET="$(compgen -G "$XDG_RUNTIME_DIR/niri.*.sock" | head -1)"
    export NIRI_SOCKET
    # Socket name is niri.<wayland-display>.<pid>.sock
    niri_display="$(basename "$NIRI_SOCKET" | cut -d. -f2)"
    wait_for 100 niri msg version
}

stop_niri() {
    kill "$niri_pid" 2> /dev/null || true
    wait "$niri_pid" 2> /dev/null || true
    unset NIRI_SOCKET
}

nwin() { niri msg --json windows | jq length; }
more_windows_than() { [ "$(nwin)" -gt "$1" ]; }

# Opens a deterministic test window (fixed app_id/title, no shell so the title never changes)
open_window() { # <n>
    local before
    before="$(nwin)"
    WAYLAND_DISPLAY="$niri_display" foot --app-id "fixture-$1" --title "Fixture $1" sleep 3600 \
        > "$logs/foot-$1.log" 2>&1 &
    pids+=($!)
    wait_for 100 more_windows_than "$before"
}

act() { # niri msg action ... ; logged into the scenario README
    echo "niri msg action $*" >> "$out/README.txt"
    niri msg action "$@"
    sleep 0.3
}

snapshot() { # <suffix>
    local q
    for q in version outputs workspaces windows focused-window keyboard-layouts; do
        niri msg --json "$q" | jq . > "$out/$q$1.json"
    done
}

scenario_setup() {
    case "$1" in
        idle | fullscreen | kb-switch | overview | config-reload) open_window 1 && open_window 2 ;;
        windows | workspaces) open_window 1 && open_window 2 && open_window 3 ;;
    esac
}

scenario_actions() {
    case "$1" in
        idle) sleep 1 ;;
        windows)
            act focus-column-left
            act focus-column-first
            act move-column-right
            act consume-or-expel-window-left
            open_window 4
            sleep 0.3
            act close-window
            act focus-column-last
            ;;
        workspaces)
            act focus-workspace-down
            act focus-workspace two
            act focus-workspace one
            act move-window-to-workspace two
            act focus-workspace 3
            act focus-workspace-up
            ;;
        fullscreen)
            act fullscreen-window
            snapshot ".fullscreen"
            act fullscreen-window
            act toggle-windowed-fullscreen
            snapshot ".windowed-fullscreen"
            act toggle-windowed-fullscreen
            ;;
        kb-switch)
            act switch-layout next
            act switch-layout next
            act switch-layout 1
            ;;
        overview)
            act toggle-overview
            act toggle-overview
            ;;
        config-reload)
            act load-config-file
            ;;
    esac
}

for s in "${scenarios[@]}"; do
    out="$root/tests/fixtures/niri/$s"
    rm -rf "$out"
    mkdir -p "$out"

    start_niri "$s"
    {
        echo "scenario: $s"
        echo "recorded: isolated headless sway + nested niri (winit), config tests/fixtures/niri/config.kdl"
        echo "niri: $(niri --version)"
        echo "actions:"
    } > "$out/README.txt"

    scenario_setup "$s"
    sleep 0.5
    snapshot ""

    niri msg --json event-stream > "$out/event-stream.jsonl" 2> "$logs/stream-$s.log" &
    stream_pid=$!
    sleep 0.5
    scenario_actions "$s"
    sleep 0.5
    kill "$stream_pid" 2> /dev/null || true
    wait "$stream_pid" 2> /dev/null || true

    snapshot ".after"
    stop_niri

    echo "$s: $(wc -l < "$out/event-stream.jsonl") events — $(jq -r 'keys[0]' "$out/event-stream.jsonl" | sort | uniq -c \
        | sort -rn | awk '{printf "%s×%s ", $2, $1}')"
done
