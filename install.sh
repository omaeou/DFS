#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
TARGET_DIR="${CONFIG_HOME}/quickshell/dfs"

if [[ "${CONFIG_HOME}" != /* ]]; then
    printf 'XDG_CONFIG_HOME must be an absolute path: %s\n' "${CONFIG_HOME}" >&2
    exit 1
fi

mkdir -p -- "${TARGET_DIR}"

# Preserve an installed config. If this is an upgrade from the pre-modular DFS
# layout, migrate the old config at quickshell/config.json into quickshell/dfs.
config_backup=""
if [[ -f "${TARGET_DIR}/config.json" ]]; then
    config_backup="$(mktemp)"
    cp -- "${TARGET_DIR}/config.json" "${config_backup}"
elif [[ -f "${CONFIG_HOME}/quickshell/config.json" ]]; then
    config_backup="$(mktemp)"
    cp -- "${CONFIG_HOME}/quickshell/config.json" "${config_backup}"
fi
if [[ -n "${config_backup}" ]]; then
    trap 'rm -f -- "${config_backup}"' EXIT
fi

cp -a -- "${ROOT_DIR}/shell/." "${TARGET_DIR}/"
if [[ -n "${config_backup}" ]]; then
    cp -- "${config_backup}" "${TARGET_DIR}/config.json"
fi

printf '\nDFS shell files installed to:\n  %s\n\n' "${TARGET_DIR}"
printf 'Start the shell with:\n  qs -p %q\n\n' "${TARGET_DIR}/shell.qml"
printf 'Build and start the Go daemon separately from the repository:\n'
printf '  mkdir -p "$HOME/.local/bin" && cd %q && go build -o "$HOME/.local/bin/dfs-daemon" .\n' "${ROOT_DIR}/daemon"
printf 'Then add these commands to your Hyprland config (adjust paths as needed):\n'
printf '  exec-once = $HOME/.local/bin/dfs-daemon\n'
printf '  exec-once = qs -p %q\n' "${TARGET_DIR}/shell.qml"
