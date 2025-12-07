# AGRR Weather Command Empty Output Issue

## 問題の概要

`agrr weather`コマンドが正常終了（exit code 0）するが、出力ファイルが空（0 bytes）になる問題が発生しています。

## 再現条件

```bash
agrr weather \
  --location 35.5014,134.235 \
  --start-date 2025-11-27 \
  --end-date 2025-12-04 \
  --data-source noaa \
  --output /tmp/weather_output.json \
  --json
```

**結果:**
- Exit code: 0（正常終了）
- stdout/stderr: 空
- 出力ファイル: 0 bytes（空）

## 原因

**NOAAデータソースが日本の位置ではデータを提供できない**

- helpによると、NOAAは「US + India 66 stations, 2000+」と記載
- 日本の位置（35.5014, 134.235）ではNOAAデータが利用不可
- デーモンは正常終了するが、データが取得できないため空ファイルを生成

## 検証結果

同じパラメータで各データソースをテスト：

| データソース | 結果 | ファイルサイズ | レコード数 |
|------------|------|--------------|-----------|
| noaa | ❌ 失敗 | 0 bytes | 0件 |
| jma | ✅ 成功 | 2601 bytes | 8件 |
| openmeteo | ✅ 成功 | 2716 bytes | 8件 |

## 推奨対応

1. **データが取得できない場合のエラーハンドリング**
   - 現在: exit code 0で空ファイルを返す
   - 推奨: データが取得できない場合は適切なエラーコードとメッセージを返す

2. **データソースの自動選択**
   - 位置に応じて適切なデータソースを自動選択（例: 日本→jma、その他→openmeteo）

3. **警告メッセージ**
   - データが取得できない場合、stderrに警告メッセージを出力

## 関連ファイル

- `app/services/agrr_service.rb` (58-59行目): 空ファイル検出でエラーを発生
- `app/gateways/agrr/base_gateway_v2.rb`: コマンド実行処理
- `app/jobs/fetch_weather_data_job.rb`: 天気データ取得ジョブ

## テストコマンド

```bash
# 再現テスト（NOAA - 失敗）
bin/agrr_client weather --location 35.5014,134.235 \
  --start-date 2025-11-27 --end-date 2025-12-04 \
  --data-source noaa --output /tmp/test.json --json

# 成功例（JMA）
bin/agrr_client weather --location 35.5014,134.235 \
  --start-date 2025-11-27 --end-date 2025-12-04 \
  --data-source jma --output /tmp/test.json --json
```


