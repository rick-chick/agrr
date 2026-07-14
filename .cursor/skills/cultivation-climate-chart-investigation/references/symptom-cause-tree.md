# 症状 → 原因候補

調査時は上から順に **観測で潰す**（debug 分析スクリプト・agrr CLI 再実行）。

## A. チャート終了が早い / 積算 GDD が要求に届かない

| 候補 | 確認方法 | 典型サイン |
|------|----------|------------|
| **A1. 気象 series に栽培開始〜の日が無い** | `analyze_debug_weather.py`; progress CLI の first record date | `data` が `prediction_start_date`（当日）からしか無い; ギャップ 100日超 |
| **A2. 観測マージがスキップ** | interactor ログ; policy が `skip?` | display 窓のみ・今日以前に栽培開始が無い（**修正済: 栽培期間ベース**） |
| **A3. DB 観測が古い** | `prediction_input` の末尾日; `latest_weather_date` | 学習終了が数ヶ月前で止まっている |
| **A4. プランキャッシュが古い世代** | `allocation_weather` は連続だが `progress_weather` は欠損 | 予測再実行後に progress だけ古い cache |
| **A5. completion_date で打ち切り** | `build_daily_gdd` + DB の completion | weather は足りるが mapper が `start..completion` のみ |
| **A6. apply_display_range** | API `debug_info.display_range` | ガント窓と栽培期間の交差でさらに短くなる |

**A1 + A5** の組み合わせが最多（欠損中は GDD ほぼ進まず、完了日でグラフ終了）。

## B. adjust / allocate / progress で数値が食い違う

| 候補 | 確認方法 |
|------|----------|
| **B1. 別 weather ファイル** | 同日 ts の `allocation_weather` vs `progress_weather` vs `adjust_weather` を分析スクリプト比較 |
| **B2. agrr サブコマンド差** | 同一 weather + crop で `progress` vs `optimize adjust` の完了日・GDD |
| **B3. adjust 後 DB 未反映** | `adjust_moves` の `to_start_date` と API 上の cultivation |
| **B4. growth_days は暦日** | `growth_days` ≠ GDD 到達までの progress 日数 |

allocate の `accumulated_gdd` をチャート完了の根拠にしない。

## C. add_crop 後だけおかしい

| 候補 | 確認方法 |
|------|----------|
| **C1. 連鎖 adjust** | 直後の `adjust_*` debug |
| **C2. 新規 cultivation の期間** | adjust 結果の allocation |
| **C3. 作物プロファイル差** | `adjust_crops` vs `progress_crop` |

## D. 予測ジョブは成功したのに欠損がある

| 候補 | 確認方法 |
|------|----------|
| **D1. 当年観測が空** | `get_current_year_data` 相当の DB 期間に行が無い |
| **D2. メタと data の不一致** | `prediction_start_date` は今日だが `data` にそれ以前の観測ブロックあり（allocate 時は正常なことあり） |
| **D3. FetchWeather 未追従** | `FetchWeatherDataJob` の取得終了日 |

## 修正の優先順位（アプリ側）

1. 栽培期間をカバーする **連続気象**を progress/adjust に渡す（マージ・窓ポリシー）
2. DB 観測の追従（運用 / FetchWeather）
3. チャート UX（要求 GDD 未達フラグ・系列延長）は気象修正後に判断
4. agrr adjust vs progress の整合は agrr 側チケット
