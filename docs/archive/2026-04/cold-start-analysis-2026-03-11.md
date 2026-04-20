# Cloud Run コールドスタート 起動時間分析 (2026-03-11)

## 調査結果サマリ

| 指標 | 値 |
|-----|-----|
| **総コールドスタート時間** | **14〜22秒** |
| **start_app.sh 合計** | 5〜6秒 |
| **Rails/Puma 起動** | 10〜16秒 |
| **Litestream リストア** | ✅ 成功（全DB GCS から復元） |
| **マイグレーション** | スキップ（スキーマ最新） |

過去分析（2026-03-10）で指摘されていた「約4分のコールドスタート」は**発生していない**。Litestream リストアが成功し、スキーマが最新のためマイグレーションがスキップされ、起動時間は大幅に短縮されている。

---

## 直近コールドスタート実測値（過去7日間）

### 総起動時間（Instance Start → Listening）

| 日時 | 開始 | 完了 | 所要時間 |
|------|------|------|----------|
| 2026-03-11 00:08 | 00:08:21.476 | 00:08:43.469 | **22秒** |
| 2026-03-10 20:58 | 00:58:13.220 | 00:58:34.083 | **21秒** |
| 2026-03-10 19:00 | 19:00:04.165 | 19:00:17.837 | **14秒** |
| 2026-03-10 18:00 | 18:00:02.846 | 18:00:23.465 | **21秒** |
| 2026-03-10 16:38 | 16:38:43.410 | 16:38:56.854 | **13秒** |
| 2026-03-10 16:16 | 16:16:14.432 | 16:16:35.414 | **21秒** |
| 2026-03-10 13:32 | 13:32:16.579 | 13:32:37.540 | **21秒** |

**中央値: 約21秒**

---

## 詳細タイムライン（2026-03-11 00:08 の事例）

```
時刻              | イベント
------------------|----------------------------------------------------------
00:08:21.476      | Cloud Run: Starting new instance (AUTOSCALING)
00:08:21.911      | start_app.sh 開始（コンテナ初期化: ~0.4秒）
00:08:21.915      | Phase 1: 4 DB 並列リストア開始
00:08:23.804      | ✓ queue DB restored (2s)
00:08:24.328      | ✓ cable DB restored (3s)
00:08:24.371      | ✓ cache DB restored (3s)
00:08:24.391      | ✓ primary DB restored (3s)
00:08:24.475      | ✓ Schema up to date, skipping migration
00:08:24.478      | Phase 1 完了 (3s)
00:08:24.480      | Phase 2: PRAGMA 設定
00:08:24.523      | Phase 2 完了 (0s)
00:08:24.525      | Phase 3: Litestream / Solid Queue / agrr daemon
00:08:24.531      | ✓ Litestream started (0s)
00:08:24.534      | ✓ Solid Queue worker started
00:08:24.535      | Waiting 3s for Solid Queue (SOLID_QUEUE_BOOT_DELAY)
00:08:27.547      | ✓ agrr daemon start initiated
00:08:27.552      | === Startup Timing Summary ===
                  | Phase 1: 3s, Phase 2: 0s, Phase 3: 3s, Total: 6s
00:08:27.552      | exec bundle exec rails server
00:08:32.789      | => Booting Puma（Rails ロード: ~5.2秒）
00:08:35.000      | Google OAuth configured
00:08:36.443      | Solid Queue Supervisor started
00:08:37.205      | ✓ agrr daemon started
00:08:43.468      | * Listening on http://0.0.0.0:3000
```

### フェーズ別所要時間（2026-03-11 00:08）

| フェーズ | 所要時間 | 内訳 |
|----------|----------|------|
| **コンテナ初期化** | ~0.4秒 | Instance start → start_app.sh 開始 |
| **Phase 1** | 3秒 | GCS からの DB リストア（並列）、マイグレーションスキップ |
| **Phase 2** | 0秒 | PRAGMA 設定 |
| **Phase 3** | 3秒 | Litestream + Solid Queue + SOLID_QUEUE_BOOT_DELAY(3s) |
| **start_app.sh 合計** | **6秒** | |
| **Rails/Puma 起動** | **~16秒** | exec → Listening |
| **総コールドスタート** | **~22秒** | |

---

## DB リストア状況

直近 7 日間のログでは、**全コールドスタートで Litestream リストアが成功**している。

- primary: 1〜3秒で GCS から復元
- queue: 0〜2秒で GCS から復元
- cache: 2〜3秒で GCS から復元
- cable: 1〜3秒で GCS から復元

「starting fresh」は検出されず。以前の分析で指摘されていたリストア失敗は解消している。

---

## マイグレーション実行時の起動時間

マイグレーションが必要な場合は起動が長くなる（例: 新規デプロイ後、SOLID_QUEUE_RESET_ON_DEPLOY=true 時）。

| 日時 | 内容 | マイグレーション時間 |
|------|------|---------------------|
| 2026-03-10 09:17 | CreateSolidQueueTables + AddUniqueIndexes | 8秒 |
| 2026-03-10 09:08 | 同上 | 4秒 |
| 2026-03-10 08:29 | 同上 | 9秒 |
| 2026-03-10 08:08 | 同上 | 7秒 |
| 2026-03-10 07:52 | 同上 | 10秒 |

これらは軽量マイグレーションのみ。**LoadAllFixtures（~90秒）** が走るケース（レプリカなし・フルマイグレーション）は直近では発生していない。

---

## 起動時間のボトルネック

### 現状の内訳（リストア成功時）

| 要因 | 推定時間 | 備考 |
|------|----------|------|
| **Rails/Puma 起動** | **10〜16秒** | 最大の要因。bundle load、OAuth、Solid Queue 初期化など |
| **DB リストア** | 2〜3秒 | 4 DB 並列で GCS から取得 |
| **SOLID_QUEUE_BOOT_DELAY** | 3秒 | 固定 sleep |
| **その他（Litestream、PRAGMA 等）** | < 1秒 | |
| **コンテナ初期化** | ~0.4秒 | Cloud Run オーバーヘッド |

### Rails 起動の内訳（推定）

- exec → Booting Puma: ~5秒（Ruby/bundle/アプリロード）
- Booting Puma → Listening: ~11秒（Puma、OAuth、DB 接続、Solid Queue プロセス等）

---

## 設定状況

### startupProbe（Cloud Run）

```yaml
initialDelaySeconds: 240   # 4分（旧 4 分シナリオ想定）
periodSeconds: 10
timeoutSeconds: 10
failureThreshold: 36
```

現状のコールドスタートが 14〜22 秒のため、`initialDelaySeconds` を **60〜90 秒** 程度に短縮可能。プローブ開始までの無駄な待機を減らせる。

### その他

- `run.googleapis.com/startup-cpu-boost: true` 有効
- `MIN_INSTANCES=0`（スケールゼロ）
- `SOLID_QUEUE_RESET_ON_DEPLOY=false`

---

## 改善提案（優先度順）

### 高優先度

1. **startupProbe の initialDelaySeconds 見直し**
   - 現在: 240秒
   - 提案: 60〜90秒（現状のコールドスタート実績に合わせる）
   - 効果: ヘルスチェック開始までの待機時間短縮

### 中優先度

2. **SOLID_QUEUE_BOOT_DELAY の検証**
   - 現在: 3秒固定
   - 0〜1秒で Solid Queue が安定して起動するか検証し、可能なら短縮

3. **Rails 起動の最適化**
   - 起動の 10〜16秒の大半を占める
   - `config.eager_load` の確認、不要な初期化の遅延など検討

### 低優先度

4. **MIN_INSTANCES=1 の検討**
   - コールドスタートを回避する場合
   - 常時インスタンス維持のコストとのトレードオフ

---

## 過去分析との比較

| 項目 | 2026-03-10 分析 | 2026-03-11 実測 |
|------|-----------------|-----------------|
| Litestream リストア | 失敗（starting fresh） | ✅ 成功 |
| マイグレーション | 毎回実行（~4分） | スキップ（0秒） |
| 総起動時間 | 232〜251秒 | 14〜22秒 |
| Phase 1 | 232〜251秒 | 2〜3秒 |

リストア成功とマイグレーションスキップにより、起動時間は **約 10〜15 倍** 短縮されている。

---

## Rails 起動プロファイリング / Bootsnap 設定メモ

ボトルネック特定用のツール:

```bash
# コールドブート計測（rake）
bundle exec rails boot:profile

# 本番相当
RAILS_ENV=production bundle exec rails boot:profile

# シェルスクリプト（time で実時間表示）
./scripts/boot_profile.sh production

# rbspy でフレームグラフ
rbspy record -f summary -- bundle exec rails server
```

### Bootsnap/BOOTSNAP_READONLY 設定と今後の計測

- 本番環境の `.env.gcp` に **`BOOTSNAP_READONLY=1`** を追加し、コンテナ起動時に Bootsnap キャッシュを読み取り専用で利用するようにした。
- Docker ビルド時に `bundle exec bootsnap compile --gemfile` を実行し、**Gemfile 変更時に Bootsnap キャッシュを事前生成**するようにした。
- この状態でのコールドスタート時間（Instance Start → Listening）を、今後のリリースで継続的に計測すること。
  - 例: 変更前後で `gcloud logging read` による起動ログを比較し、**Rails/Puma 起動部分（Booting Puma → Listening）の変化**を確認する。

---

## 新シーケンス: DB ブートストラップ並列化（2026-03-11 以降）

DB リストア＋マイグレーション＋Litestream/agrr をバックグラウンドで実行し、Rails サーバーを直ちに起動する構成に変更した。

- `Starting new instance` の直後から `run_db_bootstrap &` で Phase 1〜3 をバックグラウンド開始
- メインはすぐ `exec bundle exec rails server` に進む
- 効果: Instance Start → Booting Puma までの同期待ちがほぼゼロに近づき、総コールドスタート時間が Rails ブート時間に収束

### 新シーケンスでの計測ポイント

| 区間 | ログキー | 意味 |
|------|----------|------|
| Instance → Rails ブート開始 | `Starting new instance` → `=> Booting Puma` | コンテナ初期化＋Rails プロセス起動開始 |
| Rails ブート | `=> Booting Puma` → `Listening on http://0.0.0.0:3000` | Rails/Puma 起動時間 |
| DB ブートストラップ | `DB bootstrap started` → `DB bootstrap finished` | Phase 1〜3 の合計（並列進行） |

### DB ブートストラップ関連ログ

- `DB bootstrap started (PID: ...)` … バックグラウンド開始
- `DB bootstrap finished (took Ns total)` … Phase 1〜3 完了

---

## 参考: ログ取得コマンド

```bash
# コールドスタート関連ログ（新シーケンス対応）
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND (textPayload=~"Starting new instance" OR textPayload=~"DB bootstrap started" OR textPayload=~"DB bootstrap finished" OR textPayload=~"Booting Puma" OR textPayload=~"Listening on http")' --limit=80 --format="value(timestamp,textPayload)" --freshness=7d --project=agrr-475323

# DB リストア結果
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND textPayload=~"restored from GCS|starting fresh"' --limit=50 --format="value(timestamp,textPayload)" --freshness=7d --project=agrr-475323
```
