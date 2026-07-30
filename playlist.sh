#!/bin/bash

[ -t 0 ] && stty -ixon >>/dev/null

filename=$1
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PLAYLIST_DIR="$XDG_DATA_HOME/play/playlists"
mkdir -p "$PLAYLIST_DIR" >>/dev/null
filepath="$PLAYLIST_DIR/${filename}.txt"

if [ $# -lt 1 ]; then
  echo "Usage: playlist filename [-l] [-s] [-n] [-d] [-t] [-k]" >&2
  echo "Playlist dir: ~/.local/share/play/playlists" >&2
  exit 1
fi

filename=$1
shift

loop=false
shuffle=false
download=false
big_lyrics=false
kitty=false

for arg in "$@"; do
  case $arg in
  -l) loop=true ;;
  -s) shuffle=true ;;
  -d) download=true ;;
  -t) big_lyrics=true ;;
  -k) kitty=true ;;
  *)
    echo "Unknown option: $arg" >&2
    exit 1
    ;;
  esac
done

if [ ! -f "$filepath" ]; then
  echo "File not found: $filepath" >&2
  exit 1
fi

mapfile -t original_lines <"$filepath"

quit=false

if command -v play >/dev/null 2>&1; then
  PLAY_BIN="play"
else
  PLAY_BIN="$(cd "$(dirname "$0")" && pwd)/play"
fi

play_playlist() {
  local lines=("${@}")
  local idx=0

  while [ "$idx" -lt "${#lines[@]}" ]; do
    if $quit; then
      break
    fi

    line="${lines[$idx]}"
    local play_args=("$line")
    if $download; then
      play_args+=(-d)
    elif ! $NOTIFY; then
      play_args+=(-n)
    fi
    $big_lyrics && play_args+=(-t)
    $kitty && play_args+=(-k)
    "$PLAY_BIN" "${play_args[@]}"

    rc=$?
    case "$rc" in
    12)
      if [ "$idx" -gt 0 ]; then
        idx=$((idx - 1))
      fi
      ;;
    13)
      quit=true
      ;;
    *)
      idx=$((idx + 1))
      ;;
    esac
  done
}

if $loop; then
  while ! $quit; do
    if $shuffle; then
      mapfile -t shuffled_lines < <(printf '%s\n' "${original_lines[@]}" | shuf)
      play_playlist "${shuffled_lines[@]}"
    else
      play_playlist "${original_lines[@]}"
    fi
  done
else
  if $shuffle; then
    mapfile -t shuffled_lines < <(printf '%s\n' "${original_lines[@]}" | shuf)
    play_playlist "${shuffled_lines[@]}"
  else
    play_playlist "${original_lines[@]}"
  fi
fi
