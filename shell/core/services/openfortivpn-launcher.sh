#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DFS_VPN_HOST:-}" || -z "${DFS_VPN_USERNAME:-}" ]]; then
    printf 'VPN host and username are required.\n' >&2
    exit 2
fi

for value in "$DFS_VPN_HOST" "$DFS_VPN_USERNAME" "${DFS_VPN_PASSWORD:-}" "${DFS_VPN_OTP:-}"; do
    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
        printf 'VPN credentials cannot contain line breaks.\n' >&2
        exit 2
    fi
done

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
config_file="$(mktemp "${runtime_dir%/}/dfs-vpn.XXXXXX")"
chmod 600 "$config_file"

if [[ -n "${DFS_VPN_CONFIG:-}" ]]; then
    if [[ ! -r "$DFS_VPN_CONFIG" ]]; then
        rm -f -- "$config_file"
        printf 'VPN config file is not readable.\n' >&2
        exit 2
    fi
    cat -- "$DFS_VPN_CONFIG" > "$config_file"
    printf '\n' >> "$config_file"
fi

{
    printf 'host = %s\n' "$DFS_VPN_HOST"
    printf 'port = %s\n' "${DFS_VPN_PORT:-443}"
    printf 'username = %s\n' "$DFS_VPN_USERNAME"
    printf 'password = %s\n' "${DFS_VPN_PASSWORD:-}"
    if [[ -n "${DFS_VPN_OTP:-}" ]]; then
        printf 'otp = %s\n' "$DFS_VPN_OTP"
    fi
} >> "$config_file"

read -r -a client_command <<< "${DFS_VPN_CLIENT_COMMAND:-openfortivpn}"
if ((${#client_command[@]} == 0)); then
    rm -f -- "$config_file"
    printf 'OpenFortiVPN command is empty.\n' >&2
    exit 2
fi

env -u DFS_VPN_USERNAME -u DFS_VPN_PASSWORD -u DFS_VPN_OTP \
    "${client_command[@]}" --config "$config_file" &
client_pid=$!
cleanup() {
    if [[ -n "${client_pid:-}" ]]; then
        kill -TERM "$client_pid" 2>/dev/null || true
        wait "$client_pid" 2>/dev/null || true
    fi
    rm -f -- "$config_file"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

set +e
wait "$client_pid"
result=$?
client_pid=""
exit "$result"
