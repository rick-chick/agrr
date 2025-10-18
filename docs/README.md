# ドキュメントガイド

AGRRプロジェクトのドキュメントは、用途別に整理されています。

---

## 🚀 運用担当者向け

### まず読むべきドキュメント

1. **[DEPLOYMENT_GUIDE.md](operations/DEPLOYMENT_GUIDE.md)** ⭐️
   - デプロイ手順
   - ロールバック方法
   - データベース管理
   - メンテナンス

2. **[QUICK_REFERENCE.md](operations/QUICK_REFERENCE.md)** ⭐️
   - よく使うコマンド集
   - 緊急時の対応コマンド

3. **[OPERATIONS_SUMMARY.md](operations/OPERATIONS_SUMMARY.md)**
   - 運用の全体像
   - アーキテクチャ
   - コスト情報
   - スケーリング戦略

### 参考資料

4. **[AWS_DEPLOY.md](operations/AWS_DEPLOY.md)**
   - 旧AWS App Runner構成（参考用）

---

## 👨‍💻 開発者向け

### 開発環境セットアップ

1. **[プロジェクトREADME](../README.md)** ⭐️
   - クイックスタート
   - 開発環境の構築

2. **[GOOGLE_OAUTH_SETUP.md](development/GOOGLE_OAUTH_SETUP.md)**
   - Google OAuth認証の設定

3. **[TEST_GUIDE.md](development/TEST_GUIDE.md)**
   - テストの書き方・実行方法

### デバッグ・エラー対応

4. **[DEBUG_GUIDE.md](development/DEBUG_GUIDE.md)**
   - デバッグ方法

5. **[ERROR_HANDLING_GUIDE.md](development/ERROR_HANDLING_GUIDE.md)**
   - エラーハンドリングのベストプラクティス

---

## 🌍 地域別データ管理

### Region Data

1. **[region/DATA_CREATION_GUIDE.md](region/DATA_CREATION_GUIDE.md)** ⭐️
   - 新しい地域データを作成するための完全ガイド
   - 他のLLMや開発者が再現できるステップバイステップ手順書

2. **[region/US_SUMMARY.md](region/US_SUMMARY.md)**
   - US region実装の詳細サマリー
   - 実際の実施結果と教訓

3. **[region/README.md](region/README.md)**
   - Region機能の概要とドキュメント一覧

### Region機能仕様

4. **[region/feature.md](region/feature.md)**
   - Region機能の仕様書

5. **[region/requirements.md](region/requirements.md)**
   - Region機能の要件定義

6. **[region/seed_data.md](region/seed_data.md)**
   - シードデータの仕様

---

## 🔍 機能・実装の詳細

### 主要機能

1. **[AI_CROP_FEATURE.md](features/AI_CROP_FEATURE.md)**
   - AI作物推薦機能の実装

2. **[CLIMATE_CHART.md](features/CLIMATE_CHART.md)**
   - 気候グラフ機能

3. **[GANTT_CHART_IMPLEMENTATION.md](features/GANTT_CHART.md)**
   - ガントチャート実装

### WebSocket・リアルタイム機能

4. **[SOLID_CABLE_IMPLEMENTATION.md](features/SOLID_CABLE_IMPLEMENTATION.md)**
   - WebSocket（Solid Cable）の実装

### 気象データ

5. **[WEATHER_DATA_FLOW.md](features/WEATHER_DATA_FLOW.md)**
   - 気象データの取得フロー

6. **[WEATHER_CHART_SETUP.md](features/WEATHER_CHART_SETUP.md)**
   - 気象グラフのセットアップ

7. **[WEATHER_JOB_IMPLEMENTATION_SUMMARY.md](features/WEATHER_JOB_IMPLEMENTATION_SUMMARY.md)**
   - 気象データ取得ジョブ

---

## 🚨 トラブルシューティング

### 過去の障害事例

1. **[DATABASE_CORRUPTION_INCIDENT_REPORT.md](troubleshooting/DATABASE_CORRUPTION_INCIDENT_REPORT.md)**
   - データベース破損の対応記録

2. **[WEATHER_JOB_RECOVERY_GUIDE.md](troubleshooting/WEATHER_JOB_RECOVERY_GUIDE.md)**
   - 気象データジョブの復旧手順

### バグ修正履歴

3. **[BUGFIX_PREDICTION_EMPTY_OUTPUT.md](troubleshooting/BUGFIX_PREDICTION_EMPTY_OUTPUT.md)**
   - 予測結果が空になる問題

4. **[BUGFIX_SESSION_AUTHORIZATION.md](troubleshooting/BUGFIX_SESSION_AUTHORIZATION.md)**
   - セッション認証の問題

5. **[NO_ALLOCATION_CANDIDATES_ERROR.md](troubleshooting/NO_ALLOCATION_CANDIDATES_ERROR.md)**
   - 割り当て候補エラー

---

## 📚 開発履歴（archive/）

レビュー、CSS最適化、実装監査など、開発過程の詳細な記録：

- CSSリファクタリング関連（5ファイル）
- デザインレビュー関連（3ファイル）
- テスト最適化関連（3ファイル）
- コードレビュー・監査（2ファイル）
- その他の実装記録（6ファイル）

**用途**: 開発の意思決定の背景を知りたい時に参照

---

## 🗺️ ドキュメントマップ

```
docs/
├── README.md                    # ← このファイル（ナビゲーション）
│
├── operations/                  # 運用担当者向け
│   ├── DEPLOYMENT_GUIDE.md     # ⭐️ デプロイ手順
│   ├── QUICK_REFERENCE.md      # ⭐️ コマンド集
│   ├── OPERATIONS_SUMMARY.md   # 運用全体像
│   └── AWS_DEPLOY.md           # 旧構成（参考）
│
├── development/                 # 開発者向け
│   ├── GOOGLE_OAUTH_SETUP.md   # OAuth設定
│   ├── TEST_GUIDE.md           # テストガイド
│   ├── DEBUG_GUIDE.md          # デバッグ方法
│   └── ERROR_HANDLING_GUIDE.md # エラー処理
│
├── region/                      # 地域別データ管理
│   ├── README.md               # 概要とドキュメント一覧
│   ├── DATA_CREATION_GUIDE.md  # ⭐️ データ作成ガイド
│   ├── US_SUMMARY.md           # US region実装サマリー
│   ├── feature.md              # Region機能仕様
│   ├── requirements.md         # 要件定義
│   └── seed_data.md            # シードデータ仕様
│
├── features/                    # 機能実装の記録
│   ├── AI_CROP_FEATURE.md
│   ├── CLIMATE_CHART.md
│   ├── GANTT_CHART_IMPLEMENTATION.md
│   ├── SOLID_CABLE_IMPLEMENTATION.md
│   ├── WEATHER_CHART_SETUP.md
│   ├── WEATHER_DATA_FLOW.md
│   └── WEATHER_JOB_IMPLEMENTATION_SUMMARY.md
│
├── troubleshooting/             # 障害対応の記録
│   ├── DATABASE_CORRUPTION_INCIDENT_REPORT.md
│   ├── WEATHER_JOB_RECOVERY_GUIDE.md
│   ├── BUGFIX_PREDICTION_EMPTY_OUTPUT.md
│   ├── BUGFIX_SESSION_AUTHORIZATION.md
│   └── NO_ALLOCATION_CANDIDATES_ERROR.md
│
└── archive/                     # 開発履歴（詳細記録）
    ├── CSS_REFACTOR_*.md       # CSSリファクタリング
    ├── DESIGN_*.md             # デザインレビュー
    ├── TEST_*.md               # テスト最適化
    └── ... (19 files)
```

---

## 🎯 よくある質問

### 「デプロイする方法は？」
→ **[operations/DEPLOYMENT_GUIDE.md](operations/DEPLOYMENT_GUIDE.md)**

### 「エラーが出た時は？」
→ **[operations/QUICK_REFERENCE.md](operations/QUICK_REFERENCE.md)** のトラブルシューティング

### 「過去に同じ問題があったか？」
→ **[troubleshooting/](troubleshooting/)** フォルダを検索

### 「この機能はどう実装されている？」
→ **[features/](features/)** フォルダを参照

### 「開発環境の構築は？」
→ **[プロジェクトREADME](../README.md)** のクイックスタート

---

**迷ったら**: [operations/QUICK_REFERENCE.md](operations/QUICK_REFERENCE.md) から始めてください！

