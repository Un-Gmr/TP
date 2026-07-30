#!/usr/bin/env bash

LOOP=false
SEARCH=""
LYRIC_OFFSET=2.0
DOWNLOAD=false
SHOW_LYRICS=true
FILEMODE=false
FILEPATH=""
LYRICS=""
COVER=""
ARTIST=""
ALBUM=""
DATE=""
UPLOADER=""
THUMB=""
DISPLAY_URL=""
KITTY_MODE=false
BIG_LYRICS=false

BASE_DIR="$HOME/songs"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/terminal-player"
MPV_SOCKET="$RUNTIME_DIR/mpv.socket"
CMD_FILE="$RUNTIME_DIR/command"
REASON_FILE="$RUNTIME_DIR/reason"
METADATA_FILE="$RUNTIME_DIR/metadata.json"
EXTRADATA_FILE="$RUNTIME_DIR/extradata.json"
MPRIS_STOP_FILE="$RUNTIME_DIR/mpris.stop"
MPRIS_LOG_FILE="$RUNTIME_DIR/mpris.log"

for dep in yt-dlp mpv jq socat jp2a figlet magick curl; do
  command -v $dep >/dev/null || {
    echo "Missing: $dep"
    exit 1
  }
done

while [[ $# -gt 0 ]]; do
  case "$1" in
  -l | -L | --loop) LOOP=true ;;
  -n | --no-lyrics) SHOW_LYRICS=false ;;
  -d) DOWNLOAD=true ;;
  -f)
    FILEMODE=true
    FILEPATH="$2"
    shift
    ;;
  -L) LOOP=true ;;
  -k|--kitty) KITTY_MODE=true ;;
  -t|--big-lyrics) BIG_LYRICS=true ;;
  *) SEARCH="$SEARCH $1" ;;
  esac
  shift
done

SEARCH=$(echo "$SEARCH" | sed 's/^ *//;s/ *$//')
SAFE_QUERY=$(echo "$SEARCH" | sed 's#[/:*?"<>|]#_#g')
DEFAULT_DIR="$BASE_DIR/$SAFE_QUERY"
mkdir -p "$BASE_DIR"

if [ -d "$DEFAULT_DIR" ] && [ "$DOWNLOAD" = false ] && [ "$FILEMODE" = false ]; then
  FILEMODE=true
  FILEPATH="$DEFAULT_DIR"
fi

if [ "$DOWNLOAD" = true ]; then
  OUTDIR="$DEFAULT_DIR"
  mkdir -p "$OUTDIR"
  METADATA=$(yt-dlp "ytsearch1:$SEARCH" -q --print-json --skip-download)
  [ -z "$METADATA" ] && { echo "No results from yt-dlp" >&2; exit 1; }
  URL=$(echo "$METADATA" | jq -r '.webpage_url')
  TITLE=$(echo "$METADATA" | jq -r '.title')
  ARTIST=$(echo "$METADATA" | jq -r '.artist // .uploader // "N/A"')
  ALBUM=$(echo "$METADATA" | jq -r '.album // "N/A"')
  DATE=$(echo "$METADATA" | jq -r '.upload_date // "N/A"')
  UPLOADER=$(echo "$METADATA" | jq -r '.uploader // "N/A"')
  THUMB=$(echo "$METADATA" | jq -r '.thumbnail // empty')

  yt-dlp -x --audio-format mp3 --audio-quality 0 \
    --embed-thumbnail --embed-metadata \
    --convert-thumbnails jpg \
    -o "$OUTDIR/%(title)s.%(ext)s" "$URL"

  [ -n "$THUMB" ] && curl -fsSL "$THUMB" -o "$OUTDIR/cover.jpg"

  if [ "$SHOW_LYRICS" = true ]; then
    PYTHON=$(command -v python3 || command -v python)
    [ -n "$PYTHON" ] && "$PYTHON" -m syncedlyrics --synced-only -o="$OUTDIR/lyrics.lrc" "$(echo "$METADATA" | jq -r '.title') - $(echo "$METADATA" | jq -r '.artist')" >/dev/null 2>&1
  fi

  jq -n \
    --arg title "$TITLE" \
    --arg artist "$ARTIST" \
    --arg album "$ALBUM" \
    --arg date "$DATE" \
    --arg uploader "$UPLOADER" \
    --arg url "$URL" \
    --arg art_url "$THUMB" \
    --arg track_id "$(date +%s)-$$" \
    '{title:$title,artist:$artist,album:$album,date:$date,channel:$uploader,url:$url,art_url:$art_url,track_id:$track_id}' \
    >"$OUTDIR/metadata.json"

  echo "Saved to: $OUTDIR"
  exit 0
fi

if [ "$FILEMODE" = false ]; then
  METADATA=$(yt-dlp "ytsearch1:$SEARCH" -q --print-json --skip-download)
  [ -z "$METADATA" ] && { echo "No results from yt-dlp" >&2; exit 1; }
  URL=$(echo "$METADATA" | jq -r '.webpage_url // empty')
  [ -z "$URL" ] && { echo "Failed to extract URL from yt-dlp output" >&2; exit 1; }
  TITLE=$(echo "$METADATA" | jq -r '.title // "N/A"')
  ARTIST=$(echo "$METADATA" | jq -r '.artist // .uploader // "N/A"')
  ALBUM=$(echo "$METADATA" | jq -r '.album // "N/A"')
  DATE=$(echo "$METADATA" | jq -r '.upload_date // "N/A"')
  UPLOADER=$(echo "$METADATA" | jq -r '.uploader // "N/A"')
  THUMB=$(echo "$METADATA" | jq -r '.thumbnail // empty')

  mkdir -p "$RUNTIME_DIR"
  COVER="$RUNTIME_DIR/cover.jpg"
  [ -n "$THUMB" ] && curl -fsSL "$THUMB" -o "$COVER"
  LYRICS="$RUNTIME_DIR/lyrics.lrc"
  if [ "$SHOW_LYRICS" = true ]; then
    PYTHON=$(command -v python3 || command -v python)
    [ -n "$PYTHON" ] && "$PYTHON" -m syncedlyrics --synced-only -o="$LYRICS" "$(echo "$METADATA" | jq -r '.title') - $(echo "$METADATA" | jq -r '.artist')" >/dev/null 2>&1
  fi

  jq -n \
    --arg title "$TITLE" \
    --arg artist "$ARTIST" \
    --arg album "$ALBUM" \
    --arg date "$DATE" \
    --arg uploader "$UPLOADER" \
    --arg url "$URL" \
    --arg art_url "$THUMB" \
    --arg track_id "$(date +%s)-$$" \
    '{title:$title,artist:$artist,album:$album,date:$date,channel:$uploader,url:$url,art_url:$art_url,track_id:$track_id}' \
    >"$METADATA_FILE"
fi

if [ "$FILEMODE" = true ]; then
  if [ -d "$FILEPATH" ]; then
    MP3=$(find "$FILEPATH" -maxdepth 1 -iname "*.mp3" | head -n1)
    URL="$MP3"
    COVER=$(find "$FILEPATH" -maxdepth 1 \( -iname "*.jpg" -o -iname "*.png" \) | head -n1)
    LYRICS="$FILEPATH/lyrics.lrc"
    METADATA_FILE="$FILEPATH/metadata.json"
    EXTRADATA_FILE="$FILEPATH/extradata.json"
    TITLE=$(basename "$MP3")
    TITLE="${TITLE%.mp3}"
  else
    URL="$FILEPATH"
    TITLE=$(basename "$FILEPATH")
    TITLE="${TITLE%.mp3}"
    COVER=""
    METADATA_FILE=""
    EXTRADATA_FILE=""
  fi

  if [ -f "$URL" ] && command -v ffprobe >/dev/null 2>&1; then
    TAGS=$(ffprobe -v quiet -print_format json -show_format "$URL" 2>/dev/null)
    [ -z "$TITLE" ] && TITLE=$(echo "$TAGS" | jq -r '.format.tags.title // empty' || echo "$TITLE")
    ARTIST=$(echo "$TAGS" | jq -r '.format.tags.artist // empty' || echo "$ARTIST")
    ALBUM=$(echo "$TAGS" | jq -r '.format.tags.album // empty' || echo "$ALBUM")
  fi

  RUNTIME_METADATA_FILE="$RUNTIME_DIR/metadata.json"
  [ -n "$URL" ] && jq -n \
    --arg title "$TITLE" \
    --arg artist "$ARTIST" \
    --arg album "$ALBUM" \
    --arg url "$URL" \
    --arg track_id "$(date +%s)-$$" \
    '{title:$title,artist:$artist,album:$album,url:$url,track_id:$track_id}' \
    >"$RUNTIME_METADATA_FILE"
fi

mkdir -p "$RUNTIME_DIR"
rm -f "$MPV_SOCKET" "$CMD_FILE" "$REASON_FILE" "$MPRIS_STOP_FILE"
: >"$CMD_FILE"
: >"$REASON_FILE"
: >"$MPRIS_LOG_FILE"

DIAG_FILE="$RUNTIME_DIR/diag.log"

diag() { printf "[%s] %s\n" "$(date +%H:%M:%S.%3N)" "$*" >>"$DIAG_FILE" 2>/dev/null || true; }

cleanup() {
  local ec=$?
  diag "cleanup: exit_code=$ec REASON_FILE=$(cat "$REASON_FILE" 2>/dev/null)"
  diag "cleanup: CMD_FILE=$(cat "$CMD_FILE" 2>/dev/null)"
  if [ -n "${MPRIS_PID:-}" ]; then
    diag "cleanup: stopping MPRIS_PID=$MPRIS_PID"
    : >"$MPRIS_STOP_FILE"
    kill "$MPRIS_PID" 2>/dev/null || true
    wait "$MPRIS_PID" 2>/dev/null || true
  fi
  local p
  for p in $(pgrep -P $$ 2>/dev/null); do
    kill "$p" 2>/dev/null || true
  done
  kitty_cleanup
  rm -f "$LYRICS_FILE"
  diag "cleanup: done"
}
trap cleanup EXIT INT TERM

for pid in $(pgrep -f "terminal-player-mpris" 2>/dev/null); do
  [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null && sleep 0.2
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MPRIS_BRIDGE_MODE=""
MPRIS_BRIDGE_PATH="${MPRIS_BRIDGE:-}"
if [ "$MPRIS_BRIDGE_PATH" = "tp terminal-player-mpris" ] || [ "$MPRIS_BRIDGE_PATH" = "terminal-player-mpris" ]; then
  MPRIS_BRIDGE_MODE="tp-wrapper"
  MPRIS_BRIDGE_PATH=""
elif [ -n "$MPRIS_BRIDGE_PATH" ]; then
  MPRIS_BRIDGE_MODE="python-script"
elif command -v tp >/dev/null 2>&1; then
  MPRIS_BRIDGE_MODE="tp-wrapper"
elif [ -f "$SCRIPT_DIR/terminal_player_mpris.py" ]; then
  MPRIS_BRIDGE_MODE="python-script"
  MPRIS_BRIDGE_PATH="$SCRIPT_DIR/terminal_player_mpris.py"
fi

if [ -n "$MPRIS_BRIDGE_MODE" ]; then
  if [ "$MPRIS_BRIDGE_MODE" = "tp-wrapper" ]; then
    echo "mpris bridge command: tp terminal-player-mpris" >>"$MPRIS_LOG_FILE"
  else
    echo "mpris bridge path: $MPRIS_BRIDGE_PATH" >>"$MPRIS_LOG_FILE"
  fi
  MPRIS_PYTHON=""
  for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c 'import dbus_next' >/dev/null 2>&1; then
      MPRIS_PYTHON="$py"
      break
    fi
  done

  if [ -n "$MPRIS_PYTHON" ]; then
    if [ "$MPRIS_BRIDGE_MODE" = "tp-wrapper" ]; then
      tp terminal-player-mpris --runtime-dir "$RUNTIME_DIR" >>"$MPRIS_LOG_FILE" 2>&1 &
    else
      "$MPRIS_PYTHON" "$MPRIS_BRIDGE_PATH" --runtime-dir "$RUNTIME_DIR" >>"$MPRIS_LOG_FILE" 2>&1 &
    fi
    MPRIS_PID=$!
    sleep 0.2
    if ! kill -0 "$MPRIS_PID" 2>/dev/null; then
      echo "MPRIS bridge exited early. See: $MPRIS_LOG_FILE" >&2
    fi
  else
    echo "MPRIS bridge disabled: python with dbus-next not found" >>"$MPRIS_LOG_FILE"
  fi
else
  echo "MPRIS bridge disabled: bridge script not found" >>"$MPRIS_LOG_FILE"
fi

if [ -f "$METADATA_FILE" ]; then
  TITLE=$(jq -r '.title // "'"$TITLE"'"' "$METADATA_FILE")
  ARTIST=$(jq -r '.artist // empty' "$METADATA_FILE")
  ALBUM=$(jq -r '.album // empty' "$METADATA_FILE")
  DATE=$(jq -r '.date // empty' "$METADATA_FILE")
  UPLOADER=$(jq -r '.channel // empty' "$METADATA_FILE")
  DISPLAY_URL=$(jq -r '.url // empty' "$METADATA_FILE")
  [ ! -f "$URL" ] && URL="${DISPLAY_URL:-$URL}"
fi
: "${DISPLAY_URL:=$URL}"

if [ -f "$EXTRADATA_FILE" ]; then
  [ -z "$ARTIST" ] && ARTIST=$(jq -r '.artist // empty' "$EXTRADATA_FILE")
  [ -z "$ALBUM" ] && ALBUM=$(jq -r '.album // empty' "$EXTRADATA_FILE")
  [ -z "$DATE" ] && DATE=$(jq -r '.date // empty' "$EXTRADATA_FILE")
  [ -z "$UPLOADER" ] && UPLOADER=$(jq -r '.channel // empty' "$EXTRADATA_FILE")
fi

TERM_WIDTH=$(tput cols)
COVER_WIDTH=$((TERM_WIDTH / 2))
INFO_WIDTH=$((TERM_WIDTH - COVER_WIDTH - 2))

kitty_display_image() {
  local img="$1"
  local cell_w="$2"
  [ ! -f "$img" ] && return

  local img_w img_h
  read img_w img_h < <(magick identify -format "%w %h" "$img" 2>/dev/null)
  [ -z "$img_w" ] && return

  local cell_px=${KITTY_CELL_PX:-9}
  local cell_h_px=${KITTY_CELL_HPX:-18}
  local target_px=$((cell_w * cell_px))
  local disp_w=$target_px
  local disp_h=$((disp_w * img_h / img_w))
  local img_rows=$(( (disp_h + cell_h_px - 1) / cell_h_px ))

  local b64
  b64=$(magick "$img" -resize "${disp_w}x${disp_h}" PNG:- 2>/dev/null | base64 | tr -d '\n\r')
  [ -z "$b64" ] && return 1

  local total=${#b64}
  if [ $total -le 240000 ]; then
    printf '\e_Ga=T,f=100,w=%d,h=%d,c=0,r=0;%s\e\\' "$disp_w" "$disp_h" "$b64" >/dev/tty
  else
    local chunk_size=4000 pos=0 first=true
    while [ $pos -lt $total ]; do
      local chunk="${b64:$pos:$chunk_size}"
      pos=$((pos + chunk_size))
      local more=0; [ $pos -lt $total ] && more=1
      if [ "$first" = true ]; then
        printf '\e_Ga=T,f=100,w=%d,h=%d,c=0,r=0,m=%d;%s\e\\' "$disp_w" "$disp_h" "$more" "$chunk" >/dev/tty
        first=false
      else
        printf '\e_Gm=%d;%s\e\\' "$more" "$chunk" >/dev/tty
      fi
    done
  fi

  echo "$img_rows"
}

kitty_render_text() {
  local text="$1"
  local row="$2"
  [ -z "$text" ] && return
  tput cup $row 0
  printf '\x1b]66;s=3;%s\x1b\\\n\n' "$text" >/dev/tty
}

kitty_cleanup() {
  printf '\e_Ga=d,d=I\e\\' >/dev/tty 2>/dev/null || true
}

COVER_LINES=()
NEED_KITTY_IMAGE=false
if [ "$KITTY_MODE" = true ] && [ -n "$COVER" ] && [ -f "$COVER" ]; then
  NEED_KITTY_IMAGE=true
  read img_w img_h < <(magick identify -format "%w %h" "$COVER" 2>/dev/null)
  if [ -n "$img_w" ]; then
    cell_px=${KITTY_CELL_PX:-9}
    cell_h_px=${KITTY_CELL_HPX:-18}
    target_px=$((COVER_WIDTH * cell_px))
    disp_w=$target_px
    disp_h=$((disp_w * img_h / img_w))
    img_rows=$(( (disp_h + cell_h_px - 1) / cell_h_px ))
    for ((i = 0; i < img_rows; i++)); do
      COVER_LINES+=("")
    done
  fi
elif [ -n "$COVER" ] && [ -f "$COVER" ]; then
  mapfile -t COVER_LINES < <(jp2a --colors --fill --width=$COVER_WIDTH "$COVER")
fi

INFO_LINES=(
  "Title:   $TITLE"
  "Artist:  $ARTIST"
  "Album:   $ALBUM"
  "Date:    $DATE"
  "Channel: $UPLOADER"
  "URL:     $DISPLAY_URL"
  "Percent: 00:00:00 / 00:00:00 (0%)"
  "Volume:  100%"
)

INFO_LABELS=("Title:   " "Artist:  " "Album:   " "Date:    " "Channel: " "URL:     " "Percent: " "Volume:  ")
INFO_VALUES=("$TITLE" "$ARTIST" "$ALBUM" "$DATE" "$UPLOADER" "$DISPLAY_URL" "00:00:00 / 00:00:00 (0%)" "100%")
SCROLL_TICK=0
RENDER_EVERY=5

redraw_info_line() {
  local i=$1
  local scroll_off=$2
  local label="${INFO_LABELS[$i]}"
  local value="${INFO_VALUES[$i]}"
  local label_len=${#label}
  local value_w=$((INFO_WIDTH - label_len))
  [ $value_w -le 0 ] && value_w=1
  tput cup $i $((COVER_WIDTH + 2))
  printf "%s" "$label"
  local display_text
  if [ ${#value} -le $value_w ]; then
    display_text="$value"
  else
    local max_off=$((${#value} - value_w))
    local pos=$((scroll_off % (max_off + 1)))
    display_text="${value:$pos:$value_w}"
  fi
  if [ "$label" = "URL:     " ] && [ -n "$value" ]; then
    printf '\e]8;;%s\e\\' "$value"
    printf "%-${value_w}s" "$display_text"
    printf '\e]8;;\e\\'
  else
    printf "%-${value_w}s" "$display_text"
  fi
  tput el
}

redraw_info_lines() {
  local scroll_off=$1
  for ((i = 0; i < ${#INFO_LABELS[@]}; i++)); do
    redraw_info_line $i $scroll_off
  done
}

clear
if [ "$NEED_KITTY_IMAGE" = true ]; then
  kitty_display_image "$COVER" "$COVER_WIDTH" >/dev/null
fi
max_lines=${#COVER_LINES[@]}
[ ${#INFO_LABELS[@]} -gt $max_lines ] && max_lines=${#INFO_LABELS[@]}
for ((i = 0; i < ${#COVER_LINES[@]}; i++)); do
  printf "%-${COVER_WIDTH}s\n" "${COVER_LINES[i]}"
done
redraw_info_lines $SCROLL_TICK
LYRICS_FILE=$(mktemp)
[ "$SHOW_LYRICS" = true ] && [ -f "$LYRICS" ] && cp "$LYRICS" "$LYRICS_FILE"

LAST_LYRIC=""
LYRIC_HEIGHT=24
LYRIC_START=$((${#COVER_LINES[@]} + 1))
LAST_LYRIC_SECOND=-1
LOOP_TICK=0
VOLUME_REFRESH_EVERY=50

update_percent() {
  local percent="$1"
  INFO_VALUES[6]="$percent"
  redraw_info_line 6 $SCROLL_TICK
  tput cup $((max_lines + 2)) 0
}

update_volume() {
  [ ! -S "$MPV_SOCKET" ] && return
  vol=$(echo '{ "command": ["get_property", "volume"] }' | socat - "$MPV_SOCKET" 2>/dev/null | jq -r '.data // "N/A"')
  [ -z "$vol" ] && return
  [ "$vol" = "N/A" ] && return
  vol=${vol%.*}
  INFO_VALUES[7]="${vol}%"
  redraw_info_line 7 $SCROLL_TICK
  tput cup $((max_lines + 2)) 0
}

show_lyrics() {
  local time_s="$1"
  local cur last

  cur=$(awk -v t="$time_s" -v off="$LYRIC_OFFSET" 'BEGIN { printf "%.0f", (t + off) * 1000 }')
  [ "$cur" -lt 0 ] && cur=0

  last=$(awk -F']' -v t="$cur" '
        {
            gsub(/^\[/,"",$1)
            split($1,ts,":")
            split(ts[2],ms,".")
            cur=int(ts[1]*60000 + ts[2]*1000)
            if(cur<=t) last=$2
        }
        END{ gsub(/\n/,"",last); print last }
    ' "$LYRICS_FILE")

  [ "$last" = "$LAST_LYRIC" ] && return
  LAST_LYRIC="$last"

  for ((i = 0; i < LYRIC_HEIGHT; i++)); do
    tput cup $((LYRIC_START + i)) 0
    tput el
  done

  if [ -n "$last" ]; then
    if [ "$BIG_LYRICS" = true ]; then
      kitty_render_text "$last" $LYRIC_START
    else
      tput cup $LYRIC_START 0
      figlet -f small -w $TERM_WIDTH "$last"
    fi
  fi
}

send_mpv_command() {
  [ ! -S "$MPV_SOCKET" ] && return
  echo "$1" | socat - "$MPV_SOCKET" >/dev/null 2>&1
}
queue_reason() { printf "%s" "$1" >"$REASON_FILE"; }
set_command() { printf "%s" "$1" >"$CMD_FILE"; }
read_command() {
  [ -s "$CMD_FILE" ] || return 1
  local cmd
  cmd=$(tr -d '\r\n' <"$CMD_FILE")
  diag "read_command: found '$cmd'"
  : >"$CMD_FILE"
  printf "%s" "$cmd"
}

MPV_ARGS="--no-video --keep-open=no --input-ipc-server=$MPV_SOCKET"
$LOOP && MPV_ARGS="$MPV_ARGS --loop"

parse_elapsed() {
  local elapsed="$1"
  elapsed="${elapsed%%.*}"
  IFS=':' read -r h m s <<<"0:0:0"
  parts=(${elapsed//:/ })
  if [ ${#parts[@]} -eq 3 ]; then
    h=${parts[0]}
    m=${parts[1]}
    s=${parts[2]}
  elif [ ${#parts[@]} -eq 2 ]; then
    h=0
    m=${parts[0]}
    s=${parts[1]}
  fi
  echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

[ -z "$URL" ] && { echo "Error: no URL to play" >&2; exit 1; }
diag "--- starting playback ---"
diag "URL=$URL"
diag "CMD_FILE_before_clear=$(cat "$CMD_FILE" 2>/dev/null || echo '(empty)')"
: >"$CMD_FILE"
diag "CMD_FILE_cleared"
while read -r line; do
  ((LOOP_TICK++))
  ((LOOP_TICK % RENDER_EVERY == 0)) && {
    SCROLL_TICK=$((SCROLL_TICK + 1))
    redraw_info_lines $SCROLL_TICK
  }
  if [[ "$line" =~ ^A: ]]; then
    PERCENT=${line:3}
    [ -n "$PERCENT" ] && update_percent "$PERCENT"
    current_second=$(parse_elapsed "${PERCENT%%/*}")
    [ "$current_second" -ne "$LAST_LYRIC_SECOND" ] && show_lyrics "$current_second" && LAST_LYRIC_SECOND=$current_second
  fi

  ((LOOP_TICK % VOLUME_REFRESH_EVERY == 0)) && update_volume

  if cmd=$(read_command); then
    case "$cmd" in
    stop)
      diag "cmd=stop exiting 10"
      queue_reason "stop"
      send_mpv_command '{ "command": ["stop"] }'
      exit 10
      ;;
    next)
      diag "cmd=next exiting 11"
      queue_reason "next"
      send_mpv_command '{ "command": ["stop"] }'
      exit 11
      ;;
    prev)
      diag "cmd=prev exiting 12"
      queue_reason "prev"
      send_mpv_command '{ "command": ["stop"] }'
      exit 12
      ;;
    quit)
      diag "cmd=quit exiting 13"
      queue_reason "quit"
      send_mpv_command '{ "command": ["stop"] }'
      exit 13
      ;;
    pause | play-pause | toggle) send_mpv_command '{ "command": ["cycle", "pause"] }' ;;
    play) send_mpv_command '{ "command": ["set_property", "pause", false] }' ;;
    volup)
      send_mpv_command '{ "command": ["add", "volume", 2.5] }'
      update_volume
      ;;
    voldown)
      send_mpv_command '{ "command": ["add", "volume", -2.5] }'
      update_volume
      ;;
    mute)
      send_mpv_command '{ "command": ["cycle", "mute"] }'
      update_volume
      ;;
    seekf) send_mpv_command '{ "command": ["seek", 10] }' ;;
    seekb) send_mpv_command '{ "command": ["seek", -10] }' ;;
    esac
  fi

  key=""
  read -rsn1 -t 0.05 key </dev/tty 2>/dev/null || true
  case "$key" in
  s)
    diag "key=s exiting 10"
    send_mpv_command '{ "command": ["stop"] }'
    exit 10
    ;;
  n)
    diag "key=n exiting 11"
    send_mpv_command '{ "command": ["stop"] }'
    exit 11
    ;;
  p)
    diag "key=p exiting 12"
    send_mpv_command '{ "command": ["stop"] }'
    exit 12
    ;;
  q)
    diag "key=q exiting 13"
    send_mpv_command '{ "command": ["stop"] }'
    exit 13
    ;;
  "=" | "+")
    send_mpv_command '{ "command": ["add", "volume", 5] }'
    update_volume
    ;;
  "-")
    send_mpv_command '{ "command": ["add", "volume", -5] }'
    update_volume
    ;;
  " ")
    send_mpv_command '{ "command": ["cycle", "pause"] }'
    ;;
  m)
    send_mpv_command '{ "command": ["cycle", "mute"] }'
    update_volume
    ;;
  f)
    send_mpv_command '{ "command": ["seek", 10] }'
    ;;
  b)
    send_mpv_command '{ "command": ["seek", -10] }'
    ;;
  esac

done < <(mpv $MPV_ARGS --force-media-title="$TITLE" "$URL" 2>&1)
diag "while_loop_ended_naturally"
