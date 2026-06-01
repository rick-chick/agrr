# 予測系調査フロー

## チェックリスト（順不同でよいが未確認を残さない）

- [ ] 失敗フェーズ: `fetching_weather` / `predicting_weather` / その他
- [ ] バックエンド: Rails compose / `dev-rust-stack` / GCP test
- [ ] `agrr-server` ログに `weather_prediction failed` があるか
- [ ] `tmp/debug/prediction_input_*` の有無・サイズ
- [ ] `tmp/debug/prediction_output_*` があるか（無ければ predict 未完了）
- [ ] `prediction_input` の `unique_dates`（下記スクリプト）
- [ ] DB `weather_data` の日付範囲・件数
- [ ] `WEATHER_DATA_SOURCE` / `AGRR_PREDICT_MODEL` / `AGRR_USE_MOCK`（agrr-server プロセス）
- [ ] agrr デーモン稼働・手動 `predict` / `weather` 再現

## prediction_input の日付要約

```bash
python3 << 'PY'
import json, glob, os
from collections import Counter
root = "tmp/debug"
for p in sorted(glob.glob(f"{root}/prediction_input_*.json"))[-5:]:
    d = json.load(open(p))
    times = [x.get("time") for x in d.get("data", [])]
    u = len(set(times))
    print(os.path.basename(p), "n=", len(times), "unique=", u,
          "lat=", d.get("latitude"), "min=", min(times) if times else None,
          "max=", max(times) if times else None)
    if u <= 3:
        print("  top dates:", Counter(times).most_common(3))
PY
```

`unique=1` かつ `n` が数千 → **日付パース／フォールバック** を疑う（KNOWLEDGE #1）。

## agrr-server 環境変数（実行中プロセス）

```bash
PID=$(cat /tmp/agrr-dev-rust-pids/rust.pid 2>/dev/null)
tr '\0' '\n' < /proc/$PID/environ 2>/dev/null | grep -E 'WEATHER_DATA|AGRR_PREDICT|AGRR_USE_MOCK' || true
```

## 手動 predict（debug 入力の再利用）

```bash
IN=tmp/debug/prediction_input_XXXXX.json   # 最新を指定
OUT=/tmp/agrr-predict-manual.json
bin/agrr_client predict --input "$IN" --output "$OUT" --days 30 --model lightgbm \
  --metrics temperature,temperature_max,temperature_min
ls -la "$OUT"
```

`lightgbm` でファイルが出ず `arima` で出る → KNOWLEDGE #2。

## 手動 weather（インド座標例）

```bash
bin/agrr_client weather --location "28.5844,77.2031" \
  --start-date 2024-06-01 --end-date 2024-06-05 \
  --data-source nasa-power --output /tmp/agrr-weather-test.json --json
```

## 本番 Cloud Run Job（agrr CLI・ライブ revision 非接触）

[`production-admin/scripts/run-production-agrr-cli.sh`](../../production-admin/scripts/run-production-agrr-cli.sh) — `agrr-production` と同イメージ、Job 名既定 `agrr-prod-agrr-cli-spike`。

```bash
# 開発: ローカル直叩き（デーモン任意）
lib/core/agrr weather --location 23.2599,77.4126 \
  --start-date 2025-10-16 --end-date 2026-05-30 \
  --data-source nasa-power --json --output /tmp/local-weather.json

# 本番イメージ: デーモン起動込み（スクリプトが deploy + execute + ログ poll）
.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh weather --preset bhopal-gap

# チェーン全窓（latest=2025-10-15, today≈2026-06-02 の例）
.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh weather --preset bhopal-chain-window
```

- [ ] 本番 Job で `records N` / `elapsed_sec` が出るか
- [ ] 失敗時ログに `Daemon is not running` → スクリプトの daemon start が抜けていないか
- [ ] 本番 DB で当該 `weather_location` の窓内件数が 80% 超なら chain は agrr を呼ばず return（KNOWLEDGE #6）

## SQLite（開発 DB）

```bash
sqlite3 storage/development.sqlite3 "
  SELECT MIN(date), MAX(date), COUNT(*), COUNT(DISTINCT date)
  FROM weather_data WHERE weather_location_id = <ID>;
  SELECT substr(date,1,20) FROM weather_data WHERE weather_location_id = <ID> LIMIT 2;
"
```

`date` が `...T00:00:00` 形式か `YYYY-MM-DD` のみかでリージョン／マイグレート経路が分かれる。
