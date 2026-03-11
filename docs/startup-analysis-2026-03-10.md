# Cloud Run 起動遅延 調査レポート (2026-03-10)

## 調査結果サマリ

**総起動時間: 約4分 (232〜251秒)** — Litestream リストア失敗時（フルマイグレーション）

**VACUUM 後 (2.8MB): 約18秒** — リストア成功時も 18 秒は長い。内訳調査のため `scripts/start_app.sh` に各ステップ計測を追加済み。

GCPログ分析により、起動が遅い主な原因を特定しました。

---

## 起動タイムライン（実測値）

| フェーズ | 所要時間 | 内容 |
|---------|---------|------|
| **Phase 1** | **232〜251秒** | DBリストア＋マイグレーション |
| Phase 2 | 0秒 | PRAGMA設定 |
| Phase 3 | 0秒 | Litestream / Solid Queue / agrr daemon |
| **合計** | **~4分** | Rails server 起動まで |

### Phase 1 内訳

| ステップ | 所要時間 | 備考 |
|---------|---------|------|
| Primary DB マイグレーション | **232〜249秒** | 大半を占める |
| Queue DB | 3〜12秒 | SOLID_QUEUE_RESET_ON_DEPLOY=true で新規作成 |
| Cache DB | 2〜3秒 | レプリカなしで新規 |
| Cable DB | 3秒 | レプリカなしで新規 |

---

## 根本原因

### 1. Litestream リストアが失敗している（最重要）

```
⚠ No primary database replica found, starting fresh
⚠ No cache database replica found, starting fresh
⚠ No cable database replica found, starting fresh
```

**GCS にはレプリカが存在するが、リストアが失敗している。**

- `gsutil ls` で確認: `production/primary.sqlite3/`, `production/queue.sqlite3/` 等が存在
- `generations/` 以下にもデータあり
- しかし `litestream restore` が非ゼロで終了 → スクリプトが「starting fresh」と表示

**想定される原因:**
- **Litestream バージョン**: 現在 v0.3.13 を使用。GCS のフォーマットが v0.5 系で作成されている可能性（v0.3 と v0.5 で LTX/WAL 形式が異なる）
- **IAM**: Cloud Run のサービスアカウント `cloud-run-agrr@agrr-475323.iam.gserviceaccount.com` が GCS バケットの読み取り権限を持っているか
- **認証**: Workload Identity / デフォルト SA が GCS にアクセス可能か

**結果:** コールドスタートのたびに、空のDBから全マイグレーションを実行している。

### 2. LoadAllFixtures マイグレーションが重い（87〜94秒）

```
== 20260222191715 LoadAllFixtures: migrated (89.3299s)
```

- 日本・米国の参照データ（farm, weather, crops, interaction_rules）を投入
- 使用fixture合計: **約370MB** のJSON
  - reference_weather.json: 120MB
  - us_reference_weather.json: 125MB
  - reference_crops.json: 33KB
  - us_reference_crops.json: 79KB
- 各行ごとの `find_or_initialize_by` / `save!` で逐次INSERTしており非効率

### 3. その他のデータマイグレーション（合計約1.5分）

- DataMigrationUnitedStatesReferenceTasks: 0.48s
- DataMigrationIndiaReferenceTasks: 0.40s
- DataMigrationUnitedStatesReferencePests: 0.45s
- DataMigrationIndiaReferencePests: 0.33s
- DataMigrationJapanReferencePests: 0.30s
- 栄養要件のシード: 約0.2s
- その他多数のスキーママイグレーション

### 4. MIN_INSTANCES=0 によるコールドスタート頻発

- スケールゼロ時はインスタンスが破棄される
- 次のリクエストで新規インスタンスが起動 → 毎回4分の起動が発生

---

## 改善提案（優先度順）

### 高優先度

1. **Litestream リストアの成功化**
   - GCS にレプリカは存在するが restore が失敗している
   - stderr ログで実際のエラー内容を確認
   - Litestream v0.3.13 と GCS フォーマットの互換性確認（必要なら v0.5 系へアップグレード）
   - Cloud Run SA の GCS 読み取り権限確認

2. **MIN_INSTANCES=1 の検討**
   - 本番で常時稼働が必要な場合は、コールドスタートを避ける
   - 現在 USE_AGRR_DAEMON=true だが MIN_INSTANCES=0 で上書きされている
   - `.env.gcp` の `MIN_INSTANCES=0` を削除するか `MIN_INSTANCES=1` に変更

### 中優先度

3. **LoadAllFixtures の最適化**
   - `upsert_all` を最大限活用（既に一部で使用済み）
   - 行ごとの `save!` を減らし、バルク INSERT に統一
   - 参照データを DB シードに分離し、マイグレーションから除外する検討

4. **HEALTH_INITIAL_DELAY の見直し**
   - 現在 240秒（4分）で起動プローブ開始
   - レプリカ復元で起動が短縮できれば、これを 60〜120秒程度に短縮可能

### 低優先度

5. **参照データの事前バンドル**
   - マイグレーションではなく、デプロイ時に参照DBをビルドしてイメージに含める方式の検討（運用複雑化に注意）

---

## 次に確認すべきこと

```bash
# GCS バケット内のレプリカ確認（✓ 実在確認済み）
gsutil ls -la gs://agrr-production-db/production/

# Litestream リストアの stderr を確認（エラー原因の特定）
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production"' --limit=100 --format="value(timestamp,textPayload)" --freshness=6h 2>&1 | grep -i -E "litestream|restore|error|fail"

# Litestream バージョン確認（Dockerfile.production: v0.3.13）
# v0.3 と v0.5 で GCS フォーマットが異なる可能性あり
```

---

## 参考: 起動ログ抜粋

```
Phase 1 (Database restore and migration): 251s
Phase 2 (Database configuration): 0s
Phase 3 (Service startup): 0s
=== Starting Rails server (foreground process for Cloud Run) ===
```

```
✓ primary database migrated successfully (took 240s)
== 20260222191715 LoadAllFixtures: migrated (89.3299s)
```

---

## VACUUM 後 (2.8MB) 18秒の内訳調査

### 想定されるボトルネック

| 要因 | 推定時間 | 説明 |
|------|---------|------|
| **4x `bundle exec rails db:migrate:XXX`** | **12〜16秒** | primary/queue/cache/cable 各1回ずつ = Rails を4回フル起動。1回あたり 3〜4秒 |
| **SOLID_QUEUE_BOOT_DELAY** | **3秒** | デフォルトで `sleep 3` |
| **restore_db x4** | 2〜4秒 | 2.8MB を GCS から取得 |
| **Phase 2 PRAGMA** | < 1秒 | sqlite3 による PRAGMA 設定 |

### 計測の追加（scripts/start_app.sh）

- `restore_db`: 各リストアに `(took Xs)` を追加
- `apply_pragmas`: 各DBに `(took Xs)` を追加
- Phase 3: Step 3.1〜3.3 の所要時間をログ出力
- サマリ: 疑いのある要因を明記

### 次回起動時の確認ポイント

1. `✓ primary database migrated successfully (took Xs)` など、4つの migrate の合計が 12秒前後か
2. `Step 3.2 total` が 3秒以上（SOLID_QUEUE_BOOT_DELAY 含む）か
3. restore 4回分の合計が 2〜4秒程度か

### 改善案（18秒短縮）

1. **単一 `db:migrate` に統一**  
   `db:migrate:primary` などを4回呼ぶ代わりに、全リストア後に `rails db:migrate` を1回だけ実行。Rails 起動を 4回→1回に削減し、**約 9〜12秒短縮** を見込める。

2. **SOLID_QUEUE_BOOT_DELAY の見直し**  
   0 にすると 3秒短縮可能。Solid Queue の初期化が十分に進むかは要検証。
