#!/usr/bin/env bash

set -u

shell_file="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/shell.qml"
notification_id="${SWAYNC_REPLACES_ID:-}"
if [[ -z "$notification_id" || "$notification_id" == "0" ]]; then
    notification_id="${SWAYNC_ID:-0}"
fi
[[ "$notification_id" =~ ^[0-9]{1,10}$ ]] || notification_id=0

app_name="${SWAYNC_APP_NAME:-Уведомление}"
summary="${SWAYNC_SUMMARY:-}"
body="${SWAYNC_BODY:-}"
app_name=${app_name:0:256}
summary=${summary:0:2048}
body=${body:0:8192}

exec qs -p "$shell_file" ipc call notifications receive \
    "$app_name" \
    "$summary" \
    "$body" \
    "$notification_id"
