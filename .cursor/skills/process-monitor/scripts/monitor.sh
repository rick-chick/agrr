#!/usr/bin/env bash

PID="$1"
if [ -z "$PID" ]; then
  echo "Usage: $0 <PID>" >&2
  exit 1
fi

while kill -0 "$PID" 2>/dev/null; do
  sleep 2  # 倍長時間 (2秒)
done
echo "プロセス $PID が終了しました (exit_code確認)"