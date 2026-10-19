#!/usr/bin/env bash

set -o pipefail
umask 077

HOME_DIR="${HOME:-}"
if [[ "$HOME_DIR" != /* ]]; then
    printf 'HOME must be an absolute path for equalizer state storage\n' >&2
    exit 1
fi
CACHE_DIR="$HOME_DIR/.cache/quickshell/music"
STATE_FILE="$CACHE_DIR/eq_state.json"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SOCKET_PATH="$RUNTIME_DIR/EasyEffectsServer"
if [[ "$RUNTIME_DIR" != /* ]]; then
    printf 'XDG_RUNTIME_DIR must be an absolute path for the EasyEffects socket\n' >&2
    exit 1
fi
if [[ -L "$CACHE_DIR" ]]; then
    printf 'Refusing a symlinked equalizer state directory\n' >&2
    exit 1
fi
mkdir -p -- "$CACHE_DIR" || exit 1
chmod 700 -- "$CACHE_DIR" || exit 1

write_state() {
    local preset="$1"
    shift
    python3 - "$STATE_FILE" "$preset" "$@" <<'PY'
import json
import os
import sys
import tempfile

path, preset, *raw_values = sys.argv[1:]
values = [float(value) for value in raw_values]
data = {f"b{index + 1}": values[index] for index in range(10)}
data.update({"preset": preset, "pending": False})
directory = os.path.dirname(path)
fd, temporary = tempfile.mkstemp(prefix=".eq_state-", dir=directory)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as state_file:
        json.dump(data, state_file, separators=(",", ":"))
        state_file.write("\n")
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        return
    fi
    write_state "Custom" 0 0 0 0 0 0 0 0 0 0
}

socket_commands() {
    local mode="$1"
    shift
    python3 - "$SOCKET_PATH" "$mode" "$@" <<'PY'
import socket
import sys
import time

path, mode, *commands = sys.argv[1:]
try:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(1.0)
    client.connect(path)
    client.sendall(("\n".join(commands) + "\n").encode("utf-8"))
    client.shutdown(socket.SHUT_WR)

    if mode == "get":
        stream = client.makefile("rb")
        for _ in commands:
            line = stream.readline()
            if not line:
                raise RuntimeError("EasyEffects returned fewer values than requested")
            sys.stdout.write(line.decode("utf-8", errors="replace").strip() + "\n")
    else:
        # The local server has no acknowledgement for set_property commands.
        time.sleep(0.06)
    client.close()
except Exception as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
PY
}

saved_values() {
    load_state
    jq -r '[.b1,.b2,.b3,.b4,.b5,.b6,.b7,.b8,.b9,.b10,.preset] | .[]' "$STATE_FILE"
}

read_equalizer() {
    local -a commands=()
    local -a values=()
    local preset="Custom"
    local available=false
    local index
    local remote_values=""

    mapfile -t values < <(saved_values)
    preset="${values[10]:-Custom}"

    for ((index = 0; index < 10; index++)); do
        commands+=("get_property:output:equalizer:0:left:band${index}Gain")
    done
    if remote_values=$(socket_commands get "${commands[@]}" 2>/dev/null); then
        mapfile -t values <<< "$remote_values"
        if (( ${#values[@]} == 10 )); then
            for value in "${values[@]}"; do
                if [[ ! "$value" =~ ^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]]; then
                    values=()
                    break
                fi
            done
        fi
        if (( ${#values[@]} == 10 )); then
            available=true
        fi
    fi

    if [[ "$available" != true ]]; then
        mapfile -t values < <(saved_values)
        preset="${values[10]:-Custom}"
    fi

    jq -n -c \
        --arg preset "$preset" --argjson available "$available" \
        --arg b1 "${values[0]:-0}" --arg b2 "${values[1]:-0}" \
        --arg b3 "${values[2]:-0}" --arg b4 "${values[3]:-0}" \
        --arg b5 "${values[4]:-0}" --arg b6 "${values[5]:-0}" \
        --arg b7 "${values[6]:-0}" --arg b8 "${values[7]:-0}" \
        --arg b9 "${values[8]:-0}" --arg b10 "${values[9]:-0}" \
        '{b1:($b1|tonumber? // 0), b2:($b2|tonumber? // 0),
          b3:($b3|tonumber? // 0), b4:($b4|tonumber? // 0),
          b5:($b5|tonumber? // 0), b6:($b6|tonumber? // 0),
          b7:($b7|tonumber? // 0), b8:($b8|tonumber? // 0),
          b9:($b9|tonumber? // 0), b10:($b10|tonumber? // 0),
          preset:$preset, available:$available, pending:false}'
}

set_band() {
    local band="$1"
    local value="$2"
    local -a values=()
    local -a commands=()
    local preset="Custom"
    local plugin_band

    [[ "$band" =~ ^([1-9]|10)$ ]] || return 2
    [[ "$value" =~ ^-?([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] || return 2
    awk -v value="$value" 'BEGIN { exit !(value >= -12 && value <= 12) }' || return 2
    plugin_band=$((band - 1))

    mapfile -t values < <(saved_values)
    preset="Custom"
    values[$((band - 1))]="$value"
    commands+=("set_property:output:equalizer:0:left:band${plugin_band}Gain:${value}")
    commands+=("set_property:output:equalizer:0:right:band${plugin_band}Gain:${value}")
    socket_commands set "${commands[@]}" || return 1
    write_state "$preset" "${values[@]:0:10}"
}

select_preset() {
    local preset="$1"
    local -a values=()
    local -a commands=()
    local index

    case "$preset" in
        Flat)    values=(0 0 0 0 0 0 0 0 0 0) ;;
        Bass)    values=(5 7 5 2 1 0 0 0 1 2) ;;
        Treble)  values=(-2 -1 0 1 2 3 4 5 6 6) ;;
        Vocal)   values=(-2 -1 1 3 5 5 4 2 1 0) ;;
        Pop)     values=(2 4 2 0 1 2 4 2 1 2) ;;
        Rock)    values=(5 4 2 -1 -2 -1 2 4 5 6) ;;
        Jazz)    values=(3 3 1 1 1 1 2 1 2 3) ;;
        Classic) values=(0 1 2 2 2 2 1 2 3 4) ;;
        *) return 2 ;;
    esac

    for ((index = 0; index < 10; index++)); do
        commands+=("set_property:output:equalizer:0:left:band${index}Gain:${values[index]}")
        commands+=("set_property:output:equalizer:0:right:band${index}Gain:${values[index]}")
    done
    socket_commands set "${commands[@]}" || return 1
    write_state "$preset" "${values[@]}"
}

current_preset() {
    local result
    result=$(socket_commands get "get_last_loaded_preset:output") || return 1
    printf '%s\n' "$result"
}

case "${1:-get}" in
    get) read_equalizer ;;
    set_band) set_band "${2:-}" "${3:-}" ;;
    preset) select_preset "${2:-}" ;;
    current_preset) current_preset ;;
    *) printf 'Unknown equalizer command: %s\n' "$1" >&2; exit 2 ;;
esac
