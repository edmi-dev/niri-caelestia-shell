#!/usr/bin/env bash
# Smoke-runs the built shell in an ISOLATED nested session: headless sway (pixman) -> niri (winit) with
# tests/fixtures/niri/config.kdl, a throwaway HOME and XDG dirs. Never touches the user's session or config.
#
#   nix build .#default && nix develop -c scripts/port/smoke-shell.sh [seconds] [ipc-call ...]
#
# Runs ./result/bin/caelestia-shell for <seconds> (default 15), then each "target function [args]" IPC call,
# and prints the shell log. Exits 1 if the log contains QML errors (DBus, PipeWire and inotify warnings are expected here).
# Limitation: niri's winit backend without a DRM node offers linux-dmabuf v3 only (niri 26.4.0 src/backend/winit.rs),
# quickshell then dies with "invalid version for zwp_linux_dmabuf_v1 ... get_default_feedback" right after
# "Configuration Loaded", so this only checks that the QML loads; IPC calls after that fail.
set -euo pipefail

root="${PORT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
config="$root/tests/fixtures/niri/config.kdl"
shell="$root/result/bin/caelestia-shell"
seconds="${1:-15}"
shift || true

for tool in sway niri foot; do
    command -v "$tool" > /dev/null || { echo "$tool not in PATH (use nix develop)" >&2; exit 1; }
done
[[ -x "$shell" ]] || { echo "$shell missing (run nix build .#default)" >&2; exit 1; }

tmp="$(mktemp -d)"
export XDG_RUNTIME_DIR="$tmp/run" HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache" XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/niri" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY NIRI_SOCKET DISPLAY SWAYSOCK DBUS_SESSION_BUS_ADDRESS
logs="$tmp/logs"
mkdir -p "$logs"

pids=()
cleanup() {
    local p
    for p in "${pids[@]}"; do kill "$p" 2> /dev/null || true; done
    wait 2> /dev/null || true
    rm -rf "$tmp"
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

WAYLAND_DISPLAY=wayland-1 LIBGL_ALWAYS_SOFTWARE=1 niri -c "$config" > "$logs/niri.log" 2>&1 &
pids+=($!)
wait_for 200 compgen -G "$XDG_RUNTIME_DIR/niri.*.sock"
NIRI_SOCKET="$(compgen -G "$XDG_RUNTIME_DIR/niri.*.sock" | head -1)"
export NIRI_SOCKET
WAYLAND_DISPLAY="$(basename "$NIRI_SOCKET" | cut -d. -f2)"
export WAYLAND_DISPLAY
wait_for 100 niri msg version

WAYLAND_DISPLAY="$WAYLAND_DISPLAY" foot --app-id smoke-1 sleep 600 > /dev/null 2>&1 &
pids+=($!)

QT_QPA_PLATFORM=wayland LIBGL_ALWAYS_SOFTWARE=1 QT_QUICK_BACKEND=software \
    "$shell" > "$logs/shell.log" 2>&1 &
pids+=($!)
sleep "$seconds"

for call in "$@"; do
    echo "== ipc call $call" >> "$logs/shell.log"
    # shellcheck disable=SC2086 # word splitting of the call is intended
    "$shell" ipc call $call >> "$logs/shell.log" 2>&1 || echo "== ipc call failed: $call" >> "$logs/shell.log"
    sleep 1
done

cat "$logs/shell.log"
if grep -qE 'TypeError|ReferenceError|is not a type|is not defined|Cannot assign|Unable to assign|failed to load|module .* is not installed|Configuration failed' "$logs/shell.log"; then
    echo "SMOKE: QML errors found" >&2
    exit 1
fi
echo "SMOKE: no QML errors" >&2
