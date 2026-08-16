#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
STATE_FILE="$HOME/.local/state/quickshell/states.json"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PIDFILE="$RUNTIME_DIR/imi-screenrecord.pid"

CUSTOM_PATH=$(jq -r ".screenRecord.savePath // empty" "$CONFIG_FILE" 2>/dev/null)
RECORDING_DIR="${CUSTOM_PATH:-$HOME/Videos}"
RECORDING_DIR="${RECORDING_DIR/#\~/$HOME}"

set_recording_state() {
    local state=$1 region=${2-} tmp
    mkdir -p "$(dirname "$STATE_FILE")"
    [[ -f "$STATE_FILE" ]] || echo '{}' > "$STATE_FILE"
    tmp=$(mktemp)
    jq --arg region "$region" ".record.enable = $state | .record.region = \$region" \
        "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE" 2>/dev/null || rm -f "$tmp"
}

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    pactl list sources 2>/dev/null | grep 'Name' | grep 'monitor' | head -n1 | cut -d ' ' -f2
}
getactivemonitor() {
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null
}

is_running() {
    pgrep -x wf-recorder > /dev/null 2>&1 && return 0
    pgrep -f gpu-screen-recorder > /dev/null 2>&1 && return 0
    if [[ -f "$PIDFILE" ]]; then
        local pid
        pid="$(cat "$PIDFILE" 2>/dev/null)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Toggle check: stop active recording
if is_running; then
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    pkill -INT -x wf-recorder 2>/dev/null
    pkill -INT -f gpu-screen-recorder 2>/dev/null
    if [[ -f "$PIDFILE" ]]; then
        kill -INT "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null
        rm -f "$PIDFILE"
    fi
    set_recording_state false ""
    exit 0
fi

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit 1

ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--fullscreen" ]]; then
        FULLSCREEN_FLAG=1
    fi
done

FILENAME="recording_$(getdate).mp4"
MONITOR="$(getactivemonitor)"

if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
    notify-send "Starting recording" "$FILENAME" -a 'Recorder' & disown
    set_recording_state true "fullscreen"
    echo "$$" > "$PIDFILE"
    if [[ $SOUND_FLAG -eq 1 ]]; then
        AUDIO_DEV="$(getaudiooutput)"
        if [[ -n "$AUDIO_DEV" ]]; then
            wf-recorder -o "${MONITOR:-screen}" --pixel-format yuv420p -f "./$FILENAME" --audio="$AUDIO_DEV"
        else
            wf-recorder -o "${MONITOR:-screen}" --pixel-format yuv420p -f "./$FILENAME"
        fi
    else
        wf-recorder -o "${MONITOR:-screen}" --pixel-format yuv420p -f "./$FILENAME"
    fi
else
    if [[ -n "$MANUAL_REGION" ]]; then
        region="$MANUAL_REGION"
    else
        if ! region="$(slurp 2>&1)"; then
            notify-send "Recording cancelled" "Selection was cancelled" -a 'Recorder' & disown
            exit 1
        fi
    fi

    notify-send "Starting recording" "$FILENAME" -a 'Recorder' & disown
    set_recording_state true "$region"
    echo "$$" > "$PIDFILE"
    if [[ $SOUND_FLAG -eq 1 ]]; then
        AUDIO_DEV="$(getaudiooutput)"
        if [[ -n "$AUDIO_DEV" ]]; then
            wf-recorder --pixel-format yuv420p -f "./$FILENAME" --geometry "$region" --audio="$AUDIO_DEV"
        else
            wf-recorder --pixel-format yuv420p -f "./$FILENAME" --geometry "$region"
        fi
    else
        wf-recorder --pixel-format yuv420p -f "./$FILENAME" --geometry "$region"
    fi
fi

rm -f "$PIDFILE"
set_recording_state false ""