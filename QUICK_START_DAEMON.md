# 🚀 AGRR Daemon版 - クイックスタート

## TL;DR（結論から）

```bash
# 👍 ほとんどの場合：CLI版を使う（既存のまま）
docker compose up web

# ⚡ 高頻度アクセス：Daemon版を使う（新規）
# 1. agrr binaryをビルド
cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr && cd ../../..

# 2. テスト
docker compose --profile daemon up web-daemon

# 3. デプロイ（CloudRun）
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .
gcloud run deploy agrr-app-daemon --image gcr.io/.../agrr-app:daemon --min-instances=1
```

---

## 📁 ファイル構成（CLI版は完全保持）

### ✅ 既存ファイル（CLI版）- **変更なし**

```
Dockerfile                    # CLI版Dockerfile
scripts/start_app.sh         # CLI版起動
```

### 🆕 新規ファイル（Daemon版）

```
Dockerfile.with-agrr-daemon           # Daemon版Dockerfile
scripts/start_app_with_agrr_daemon.sh # Daemon版起動
README_DAEMON.md                      # このガイド
docs/DEPLOYMENT_VARIANTS.md           # 詳細ガイド
```

---

## 🎯 使い分けフローチャート

```
最小インスタンス数=1で運用している？
│
├─ No  → CLI版を使う（コスト最適）
│
└─ Yes → リクエスト頻度は？
    │
    ├─ 低頻度（1日数回） → CLI版を使う
    │
    └─ 高頻度（1時間10回以上） → Daemon版を検討
        │
        ├─ agrr実行は頻繁？（50%以上）
        │   ├─ Yes → Daemon版を使う ⚡
        │   └─ No  → CLI版で十分
        │
        └─ コスト増OK？（+$30-50/月）
            ├─ Yes → Daemon版を使う ⚡
            └─ No  → CLI版を使う
```

---

## 📊 比較表

| 項目 | CLI版 ✅ | Daemon版 ⚡ |
|------|---------|------------|
| **agrr起動** | 2.4s（毎回） | 初回: 2.4s、2回目以降: 0.5s |
| **メモリ** | 1.5GB | 1.7GB (+200MB) |
| **最小インスタンス** | 0（推奨） | 1（推奨） |
| **月額コスト** | $0-10 | $30-50 |
| **セットアップ** | 簡単 | 要agrrビルド |
| **推奨ケース** | ほとんどの場合 | 高頻度アクセス |

---

## 🛠️ セットアップ手順

### CLI版（デフォルト、そのまま使える）

```bash
# 開発
docker compose up web

# 本番（CloudRun）
docker build -t agrr-app:cli .
gcloud run deploy agrr-app --image gcr.io/.../agrr-app:cli
```

**セットアップ不要！** 既存のまま使えます。

### Daemon版（agrrビルドが必要）

#### Step 1: agrr binaryをビルド（初回のみ）

```bash
cd lib/core/agrr_core

# ビルド（5-10分かかります）
./build_standalone.sh --onefile

# バイナリを配置
cp dist/agrr ../agrr

# 確認
ls -lh ../agrr
# -rwxr-xr-x 1 user user 113M ... ../agrr

cd ../../..
```

#### Step 2: ローカルでテスト

```bash
# Daemon版を起動
docker compose --profile daemon up web-daemon

# ブラウザで確認
# http://localhost:3001

# ログで確認
# "✓ agrr daemon started (PID: xxxx)" が表示されればOK
```

#### Step 3: 本番デプロイ

```bash
# CloudRun
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .
gcloud run deploy agrr-app-daemon \
  --image gcr.io/PROJECT_ID/agrr-app:daemon \
  --min-instances=1 \
  --memory 2Gi
```

---

## 🔄 切り替え方法

### 開発環境

```bash
# CLI版
docker compose up web

# Daemon版
docker compose --profile daemon up web-daemon
```

### 本番環境

```bash
# CLI版
docker build -t agrr-app:cli .
gcloud run deploy agrr-app --image gcr.io/.../agrr-app:cli

# Daemon版（別サービスとしてデプロイ）
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .
gcloud run deploy agrr-app-daemon --image gcr.io/.../agrr-app:daemon --min-instances=1
```

**両方を同時にデプロイすることも可能**です。

---

## ⚡ パフォーマンス測定

Daemon版の効果を確認：

```bash
# Daemon版コンテナ内で
docker compose --profile daemon exec web-daemon bash

# 1回目（daemon起動）
time /usr/local/bin/agrr weather --location 35.6762,139.6503 --days 1 --json
# → 約2.4s

# 2回目（daemonのおかげで速い）
time /usr/local/bin/agrr weather --location 35.6762,139.6503 --days 1 --json
# → 約0.5s（4.8倍高速！）
```

---

## 🐛 トラブルシューティング

### agrr binary not found

```bash
# ビルドされているか確認
ls -lh lib/core/agrr

# なければビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..
```

### daemon起動失敗

```bash
# ログ確認
docker compose --profile daemon logs web-daemon | grep daemon

# または手動確認
docker compose --profile daemon exec web-daemon \
  /usr/local/bin/agrr daemon status
```

### メモリ不足

```bash
# CloudRunの場合
gcloud run services update agrr-app-daemon --memory 2.5Gi
```

---

## 📚 詳細ドキュメント

| ドキュメント | 説明 |
|------------|------|
| [README_DAEMON.md](README_DAEMON.md) | Daemon版の詳細説明 |
| [DEPLOYMENT_VARIANTS.md](docs/DEPLOYMENT_VARIANTS.md) | 使い分けガイド |
| [AGRR_DAEMON_INTEGRATION.md](docs/AGRR_DAEMON_INTEGRATION.md) | 実装詳細 |
| [DAEMON_CLOUDRUN_ANALYSIS.md](docs/DAEMON_CLOUDRUN_ANALYSIS.md) | 技術分析 |

---

## ✅ まとめ

### CLI版を使うべき（ほとんどの場合）

- ✅ 既存のまま使える
- ✅ コストが安い
- ✅ セットアップ不要
- ✅ シンプル

### Daemon版を使うべき（特殊ケース）

以下を**すべて満たす**場合のみ：
- ✅ 最小インスタンス=1で運用
- ✅ 高頻度アクセス（1時間10回以上）
- ✅ agrr実行が頻繁（50%以上）
- ✅ コスト増が許容できる（+$30-50/月）

### 迷ったら

**CLI版から始めてください。** 必要に応じてDaemon版に移行できます。

---

## 🎉 作成されたファイル一覧

### 実装ファイル（2個）
- ✅ `Dockerfile.with-agrr-daemon`
- ✅ `scripts/start_app_with_agrr_daemon.sh`

### ドキュメント（5個）
- 📖 `QUICK_START_DAEMON.md` ← このファイル
- 📖 `README_DAEMON.md`
- 📖 `docs/DEPLOYMENT_VARIANTS.md`
- 📖 `docs/AGRR_DAEMON_INTEGRATION.md`
- 📖 `docs/DAEMON_CLOUDRUN_ANALYSIS.md`（更新）

### その他
- 🔧 `docker-compose.yml`（`web-daemon`サービス追加）
- 📝 `.daemon-version-summary.md`（ファイル対応表）

**既存のCLI版ファイルは一切変更していません！** ✅

