# Crop Task Template Backfill Guide

既存の `AgriculturalTask` と `Crop` の関連データから `CropTaskTemplate` を生成するための手順です。テンプレート化により、予定作成やAIスケジュール生成が安定して再利用できるようになります。

## 前提
- Rails アプリが起動可能であること
- 必要に応じて本番/ステージング環境でメンテナンス時間を確保すること

## 実行手順

### 1. 対象作物を確認
テンプレート化が必要な作物の ID をリストアップします（任意）。何も指定しない場合、全作物が対象になります。

### 2. Rake タスクを実行
```bash
bundle exec rake agrr:backfill_crop_task_templates
```

特定の作物 ID のみを対象にする場合は、`CROP_IDS` をカンマ区切りで指定します。

```bash
bundle exec rake agrr:backfill_crop_task_templates CROP_IDS=12,45,89
```

### 3. 結果の確認
- `crop_task_templates` テーブルにレコードが作成されているかを確認してください。
- 作物詳細画面でテンプレート一覧が表示されることを確認します。
- 予定作成モーダルでテンプレートが候補として表示されることを確認します。

### 4. ログ/エラーの確認
タスク実行中にエラーが出た場合は、ログを確認して原因を特定してください。必要に応じて対象作物の関連データ（`AgriculturalTask` に必要情報が揃っているか等）を修正して再実行します。

## ロールバック
テンプレート生成結果を取り消したい場合は、対象データを `CropTaskTemplate` から削除してください。削除後に再度タスクを実行することで再作成できます。


