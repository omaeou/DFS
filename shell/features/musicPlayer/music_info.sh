#!/usr/bin/env bash

set -o pipefail
umask 077
HOME_DIR="${HOME:-}"
if [[ "$HOME_DIR" != /* ]]; then
    printf 'HOME must be an absolute path for music cache storage\n' >&2
    exit 1
fi
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME_DIR/.cache}"
[[ "$CACHE_ROOT" == /* ]] || CACHE_ROOT="$HOME_DIR/.cache"
CACHE_DIR="$CACHE_ROOT/dfs-shell/music/covers"
if [[ -L "$CACHE_DIR" ]]; then
    printf 'Refusing a symlinked music cover cache directory\n' >&2
    exit 1
fi
mkdir -p -- "$CACHE_DIR" || exit 1
chmod 700 -- "$CACHE_DIR" || exit 1
MAX_COVER_BYTES=5242880

playerctl_safe() { timeout 1.2 playerctl "$@" 2>/dev/null | head -c 4096; }

# playerctl defaults to the first available MPRIS player, which can be a
# browser even while Spotify is the active source. Prefer a playing Spotify,
# then any other playing source, and finally a paused source.
players=$(playerctl_safe --list-all || true)
spotify_paused=""
first_paused=""
first_playing=""
selected_player=""
status=""
player_count=0

while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    (( player_count >= 16 )) && break
    ((player_count += 1))
    candidate=${candidate:0:128}
    candidate_status=$(playerctl_safe --player "$candidate" status || true)
    if [[ "$candidate_status" == "Playing" ]]; then
        if [[ "${candidate,,}" == *spotify* ]]; then
            selected_player="$candidate"
            status="$candidate_status"
            break
        elif [[ -z "$first_playing" ]]; then
            first_playing="$candidate"
        fi
    elif [[ "$candidate_status" == "Paused" ]]; then
        if [[ "${candidate,,}" == *spotify* ]]; then
            spotify_paused="$candidate"
        elif [[ -z "$first_paused" ]]; then
            first_paused="$candidate"
        fi
    fi
done <<< "$players"

if [[ -z "$selected_player" ]]; then
    selected_player="$first_playing"
    [[ -n "$selected_player" ]] && status="Playing"
fi
if [[ -z "$selected_player" ]]; then
    selected_player="$spotify_paused"
    [[ -n "$selected_player" ]] && status="Paused"
fi
if [[ -z "$selected_player" ]]; then
    selected_player="$first_paused"
    [[ -n "$selected_player" ]] && status="Paused"
fi

if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    title=$(playerctl_safe --player "$selected_player" metadata xesam:title || true)
    artist=$(playerctl_safe --player "$selected_player" metadata xesam:artist || true)
    raw_url=$(playerctl_safe --player "$selected_player" metadata mpris:artUrl || true)
    length_us=$(playerctl_safe --player "$selected_player" metadata mpris:length || true)
    position_us=$(playerctl_safe --player "$selected_player" metadata --format '{{position}}' || true)
    player_name="$selected_player"
    title=${title:0:512}
    artist=${artist:0:512}
    player_name=${player_name:0:128}

    [[ "$length_us" =~ ^[0-9]+$ ]] || length_us=1000000
    [[ "$position_us" =~ ^[0-9]+$ ]] || position_us=0
    length=$((length_us / 1000000))
    (( length > 0 )) || length=1
    position=$((position_us / 1000000))
    (( position <= length )) || position=$length
    percent=$((position * 100 / length))
    length_text=$(printf '%02d:%02d' $((length / 60)) $((length % 60)))
    position_text=$(printf '%02d:%02d' $((position / 60)) $((position % 60)))
    art_path=""

    if [[ -n "$raw_url" && ${#raw_url} -le 4096 ]]; then
        hash=$(printf '%s' "$raw_url" | sha256sum | cut -d' ' -f1)
        image="$CACHE_DIR/$hash.jpg"
        if [[ -L "$image" ]]; then
            rm -f -- "$image"
        elif [[ -f "$image" ]]; then
            cached_size=$(wc -c < "$image" 2>/dev/null || printf '0')
            if [[ ! "$cached_size" =~ ^[0-9]+$ ]] || (( cached_size == 0 || cached_size > MAX_COVER_BYTES )); then
                rm -f -- "$image"
            fi
        fi
        if [[ ! -s "$image" ]]; then
            tmp_image=$(mktemp "$CACHE_DIR/.cover-XXXXXX" 2>/dev/null || true)
            if [[ -n "$tmp_image" && "$raw_url" == https://* ]] && python3 - "$raw_url" <<'PY'
import sys
from urllib.parse import urlsplit

try:
    url = urlsplit(sys.argv[1])
    allowed = (
        url.scheme == "https"
        and url.hostname in {"i.scdn.co", "mosaic.scdn.co"}
        and url.username is None
        and url.password is None
        and url.port in (None, 443)
        and not any(ord(character) < 32 or ord(character) == 127 for character in sys.argv[1])
    )
except ValueError:
    allowed = False
sys.exit(0 if allowed else 1)
PY
            then
                if curl --silent --show-error --fail --location --max-redirs 0 \
                    --proto '=https' --proto-redir '=https' --connect-timeout 2 \
                    --max-time 4 --max-filesize "$MAX_COVER_BYTES" \
                    -A 'Mozilla/5.0' --output - "$raw_url" 2>/dev/null \
                    | head -c "$((MAX_COVER_BYTES + 1))" > "$tmp_image"; then
                    downloaded_size=$(wc -c < "$tmp_image")
                    if (( downloaded_size > 0 && downloaded_size <= MAX_COVER_BYTES )); then
                        mv -f -- "$tmp_image" "$image"
                        tmp_image=""
                    fi
                fi
            elif [[ -n "$tmp_image" && "$raw_url" == file:///* ]]; then
                local_image=$(python3 - "$raw_url" <<'PY'
import os
import sys
from urllib.parse import unquote, urlsplit

try:
    url = urlsplit(sys.argv[1])
    path = unquote(url.path)
    allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
    if url.scheme == "file" and url.netloc in ("", "localhost") and not url.query and not url.fragment \
            and not any(ord(character) < 32 or ord(character) == 127 for character in path) \
            and os.path.isabs(path) and os.path.splitext(path)[1].lower() in allowed_extensions:
        print(path)
except ValueError:
    pass
PY
                )
                if [[ -n "$local_image" && -f "$local_image" ]]; then
                    local_size=$(wc -c < "$local_image" 2>/dev/null || printf '0')
                    if [[ "$local_size" =~ ^[0-9]+$ ]] && (( local_size > 0 && local_size <= MAX_COVER_BYTES )); then
                        if cp -- "$local_image" "$tmp_image" 2>/dev/null && mv -f -- "$tmp_image" "$image"; then
                            tmp_image=""
                        fi
                    fi
                fi
            fi
            [[ -z "${tmp_image:-}" ]] || rm -f -- "$tmp_image"
            find "$CACHE_DIR" -maxdepth 1 -type f -name '*.jpg' -mtime +30 -delete 2>/dev/null || true
        fi
        [[ -f "$image" && ! -L "$image" ]] && art_path="$image"
    fi

    jq -n -c \
        --arg title "$title" --arg artist "$artist" --arg status "$status" \
        --arg lengthStr "$length_text" --arg positionStr "$position_text" \
        --argjson length "$length" --argjson position "$position" --argjson percent "$percent" \
        --arg playerName "$player_name" --arg artUrl "$art_path" \
        '{title:$title, artist:$artist, status:$status, length:$length, position:$position,
          lengthStr:$lengthStr, positionStr:$positionStr, percent:$percent,
          playerName:$playerName, source:$playerName, deviceName:"Speaker", deviceIcon:"󰓃", artUrl:$artUrl}'
else
    jq -n -c '{title:"Нет воспроизведения", artist:"", status:"Stopped", length:0,
              position:0, percent:0, lengthStr:"00:00", positionStr:"00:00",
              playerName:"", source:"Ожидание", deviceName:"Speaker", deviceIcon:"󰓃", artUrl:""}'
fi
