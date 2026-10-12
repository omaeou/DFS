#!/usr/bin/env bash

set -u

shell_file="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/shell.qml"
notification_id="${SWAYNC_REPLACES_ID:-}"
if [[ -z "$notification_id" || "$notification_id" == "0" ]]; then
    notification_id="${SWAYNC_ID:-0}"
fi

exec qs -p "$shell_file" ipc call notifications receive \
    "${SWAYNC_APP_NAME:-Уведомление}" \
    "${SWAYNC_SUMMARY:-}" \
    "${SWAYNC_BODY:-}" \
    "$notification_id"
