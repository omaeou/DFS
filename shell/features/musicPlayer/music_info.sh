#!/usr/bin/env bash

set -o pipefail
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dfs-shell/music/covers"
mkdir -p "$CACHE_DIR"

playerctl_safe() { timeout 1.2 playerctl "$@" 2>/dev/null; }

# playerctl defaults to the first available MPRIS player, which can be a
# browser even while Spotify is the active source. Prefer a playing Spotify,
# then any other playing source, and finally a paused source.
players=$(playerctl_safe --list-all || true)
spotify_paused=""
first_paused=""
first_playing=""
selected_player=""
status=""

while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
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

    if [[ -n "$raw_url" ]]; then
        hash=$(printf '%s' "$raw_url" | md5sum | cut -d' ' -f1)
        image="$CACHE_DIR/$hash.jpg"
        if [[ ! -f "$image" ]]; then
            if [[ "$raw_url" == https://i.scdn.co/* || "$raw_url" == https://mosaic.scdn.co/* ]]; then
                curl -fsSL --max-time 3 -A 'Mozilla/5.0' "$raw_url" -o "$image" || rm -f "$image"
            elif [[ "$raw_url" == file://* ]]; then
                cp "${raw_url#file://}" "$image" 2>/dev/null || true
            fi
        fi
        [[ -f "$image" ]] && art_path="$image"
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
