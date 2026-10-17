#!/usr/bin/env bash
# NIRI-PORT(U45): screen recorder used by services/Recorder.qml instead of `caelestia record` (Q10 = b).
# The CLI's version asks Hyprland for the monitor list; here the shell passes the output and fps it got from niri.
# Paths, notifications and the cli.json `record.extraArgs` option match the CLI so recordings land in the same place.
#
#   record.sh start -o <output> -f <fps> [-r] [-s]   fullscreen on <output>, or a slurp region with -r; -s adds audio
#   record.sh stop [-c]                              stop, move to the recordings dir; -c copies the file URI
#   record.sh pause                                  pause/resume

set -u

RECORDER=gpu-screen-recorder
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/record"
recording="$state_dir/recording.mp4"
notif_file="$state_dir/notifid.txt"
recordings_dir="${CAELESTIA_RECORDINGS_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings}"
cli_config="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/cli.json"

notify() {
    notify-send -a caelestia-shell "$@"
}

close_notification() {
    gdbus call --session --dest=org.freedesktop.Notifications --object-path=/org/freedesktop/Notifications \
        --method=org.freedesktop.Notifications.CloseNotification "$1" >/dev/null 2>&1
}

start() {
    local output="" fps=60 region=0 sound=0 opt
    OPTIND=1
    while getopts "o:f:rs" opt; do
        case "$opt" in
            o) output=$OPTARG ;;
            f) fps=$OPTARG ;;
            r) region=1 ;;
            s) sound=1 ;;
            *) return 2 ;;
        esac
    done

    local args=(-w)
    if [ "$region" = 1 ]; then
        local geom
        geom=$(slurp -f "%wx%h+%x+%y" </dev/null) || return 0 # selection cancelled
        args+=(region -region "$geom")
    elif [ -n "$output" ]; then
        args+=("$output")
    else
        echo "record.sh: no output given" >&2
        return 2
    fi
    args+=(-f "$fps")
    [ "$sound" = 1 ] && args+=(-a default_output)

    if [ -f "$cli_config" ]; then
        local extra
        while IFS= read -r extra; do
            args+=("$extra")
        done < <(jq -r '.record.extraArgs // [] | .[]' "$cli_config" 2>/dev/null)
    fi

    mkdir -p "$state_dir"
    # The recorder outlives this script, so detach it from our stdio and session
    setsid "$RECORDER" "${args[@]}" -o "$recording" </dev/null >/dev/null 2>&1 &
    local pid=$!

    local id
    id=$(notify -p "Recording started" "Recording...")
    printf '%s' "$id" >"$notif_file"

    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid"
        local code=$?
        close_notification "$id"
        notify "Recording failed" \
            "An error occurred attempting to start recorder. Command \`$RECORDER ${args[*]}\` failed with exit code $code"
        return 1
    fi
}

stop() {
    local clipboard=0
    [ "${1:-}" = "-c" ] && clipboard=1

    pkill -f "$RECORDER" >/dev/null
    # Wait for the recorder to finalise the file to avoid a corrupted video
    while pidof "$RECORDER" >/dev/null; do
        sleep 0.1
    done

    [ -f "$recording" ] || return 0
    mkdir -p "$recordings_dir"
    local dest
    dest="$recordings_dir/recording_$(date +%Y%m%d_%H-%M-%S).mp4"
    mv -- "$recording" "$dest"

    [ -f "$notif_file" ] && close_notification "$(cat "$notif_file")"

    local uri="file://$dest"
    [ "$clipboard" = 1 ] && printf '%s\n' "$uri" | wl-copy --type text/uri-list

    # The action notification lives as long as the user's interaction with it, so hand it to a detached shell
    (
        cd / || exit 0
        action=$(notify --action=watch=Watch --action=open=Open --action=delete=Delete \
            "Recording stopped" "Recording saved in $dest") || exit 0
        case "$action" in
            watch) exec xdg-open "$dest" ;;
            open)
                dbus-send --session --dest=org.freedesktop.FileManager1 --type=method_call \
                    /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems \
                    "array:string:$uri" "string:" || exec xdg-open "$recordings_dir"
                ;;
            delete) rm -f -- "$dest" ;;
        esac
    ) </dev/null >/dev/null 2>&1 &
    disown
}

case "${1:-}" in
    start) shift && start "$@" ;;
    stop) shift && stop "$@" ;;
    pause) pkill -USR2 -f "$RECORDER" >/dev/null ;;
    *)
        echo "usage: record.sh start -o <output> -f <fps> [-r] [-s] | stop [-c] | pause" >&2
        exit 2
        ;;
esac
