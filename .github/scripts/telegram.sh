#!/usr/bin/env bash
set -u

TG_API="https://api.telegram.org/bot${TG_BOT_TOKEN}"

tg_send() {
  local text="${1:-}" chunk
  [ -z "$text" ] && return 0
  while [ -n "$text" ]; do
    chunk="${text:0:3800}"
    curl -s "${TG_API}/sendMessage" \
      -d "chat_id=${TG_CHAT_ID}" \
      --data-urlencode "text=${chunk}" > /dev/null || true
    text="${text:3800}"
  done
}

tg_send_md() {
  local text="${1:-}" chunk
  [ -z "$text" ] && return 0
  while [ -n "$text" ]; do
    chunk="${text:0:3800}"
    curl -s "${TG_API}/sendMessage" \
      -d "chat_id=${TG_CHAT_ID}" \
      --data-urlencode "text=${chunk}" \
      -d "parse_mode=Markdown" > /dev/null || true
    text="${text:3800}"
  done
}

tg_document() {
  local path="${1:-}" caption="${2:-}"
  [ -f "$path" ] || return 0
  curl -s "${TG_API}/sendDocument" \
    -F "chat_id=${TG_CHAT_ID}" \
    -F "document=@${path}" \
    -F "caption=${caption}" > /dev/null || true
}

tg_stream_file() {
  local path="${1:-}" buf="" line
  [ -f "$path" ] || { tg_send "(log file not found: $path)"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    buf+="${line}"$'\n'
    if [ "${#buf}" -ge 3800 ]; then
      tg_send "${buf}"
      buf=""
    fi
  done < "$path"
  [ -n "$buf" ] && tg_send "${buf}"
}

tg_progress_start() {
  TG_LOG="${1:-/tmp/build.log}"
  echo 0 > "$TG_LOG.pos"
  (
    local last new_lines count
    while true; do
      last=$(cat "$TG_LOG.pos" 2>/dev/null || echo 0)
      last=$((last))
      new_lines=$(tail -n +$((last+1)) "$TG_LOG" 2>/dev/null || true)
      if [ -n "$new_lines" ]; then
        count=$(printf '%s\n' "$new_lines" | wc -l)
        count=$((count))
        tg_send "${new_lines}"
        echo $((last+count)) > "$TG_LOG.pos"
      fi
      sleep 30
    done
  ) &
  TG_PROGRESS_PID=$!
}

tg_progress_stop() {
  local log="${1:-${TG_LOG:-/tmp/build.log}}" last new_lines
  sleep 3
  last=$(cat "$log.pos" 2>/dev/null || echo 0)
  last=$((last))
  new_lines=$(tail -n +$((last+1)) "$log" 2>/dev/null || true)
  [ -n "$new_lines" ] && tg_send "${new_lines}"
  rm -f "$log.pos"
  if [ -n "${TG_PROGRESS_PID:-}" ]; then
    kill "$TG_PROGRESS_PID" 2>/dev/null || true
  fi
}