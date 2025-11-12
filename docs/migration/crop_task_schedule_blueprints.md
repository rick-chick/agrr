# Crop Task Schedule Blueprints Migration Guide

## 概要

- 参照作物ごとの GDD テンプレートを `crop_task_schedule_blueprints` に保存する。
- テンプレートはデータマイグレーションとして配布し、`TaskScheduleGeneratorService` が実行時に参照する。
- CLI 依存はテンプレート生成時のみ。運用環境ではマイグレーションを適用するだけで OK。

## スクリプト

```
bin/generate_crop_task_schedule_blueprints.rb --region jp \
  [--crop-id 42 | --crop-name トマト]
```

- `--region` は必須 (`jp` / `us` / `in` など)。
- `--crop-id` または `--crop-name` で対象作物を絞り込める。指定しない場合は、地域内の参照作物すべてが対象。
- 既存マイグレーションと同じく ASCII のみ出力する。

## 生成物

- `db/migrate/<timestamp>_data_migration_<region>_crop_task_schedule_blueprints.rb`
- `TempBlueprint`（一時モデル）経由で `insert_all` / `delete_all` を行う。
- `BLUEPRINTS` 定数にテンプレートの属性が格納される。`gdd_*`, `amount`, `time_per_sqm` は文字列として保持され、`up` 実行時に `BigDecimal` へ変換される。

## 運用上の注意

- スクリプトは AGRR デーモンを利用するため、ローカルで CLI が実行できる状態であること。
- テンプレートが 0 件になった場合は `TemplateMissingError` で本番生成が止まるため、参照作物のテンプレートは必ず維持する。
- `TaskScheduleGeneratorService` はテンプレート欠損時に CLI へフォールバックしない。

## 変更時の手順

1. 対象作物のテンプレートを CLI で再取得する（必要に応じて `--crop-id` / `--crop-name` を利用）。
2. 生成されたマイグレーションをレビューし、既存テンプレートとの差分を確認。
3. マイグレーションを適用してから `TaskScheduleGeneratorService` のテストを実行。
