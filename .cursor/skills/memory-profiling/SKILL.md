# Memory Profiling & Diagnostics

開発環境でメモリ使用量の監視・デバッグを行うスクリプト群。

## Scripts

- **visualize_memory.py** — メモリ使用量をグラフ化
- **docker_monitor_memory.sh** — Docker コンテナのメモリ監視
- **monitor_daemon_memory.sh** — agrr daemon のメモリ監視
- **view_memory_report.sh** — メモリレポート表示
- **boot_profile.sh** — ブートプロファイリング

## Usage

```bash
.cursor/skills/memory-profiling/scripts/visualize_memory.py
.cursor/skills/memory-profiling/scripts/docker_monitor_memory.sh
.cursor/skills/memory-profiling/scripts/monitor_daemon_memory.sh
.cursor/skills/memory-profiling/scripts/view_memory_report.sh
.cursor/skills/memory-profiling/scripts/boot_profile.sh
```

## Env vars

- `ENABLE_MEMORY_MONITOR=true docker compose up` — 起動時にメモリ監視有効化
