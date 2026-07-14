---
title: 遅いテスト検出時の詳細手順
---

## 目的
テスト実行後に "=== Slow tests detected (threshold: 0.5s) ===" が出ている場合の再現・特定・対応手順を示す。

## 手順
1. 該当テストをローカルで単体実行して再現性を確認する。
   - RSpec: `bundle exec rspec spec/path/to/spec.rb:NN`
   - Minitest: `rails test test/path/to/test.rb:NN`
2. プロファイリング/プロファイル出力で遅い例を特定する。
   - RSpec: `bundle exec rspec --profile`
3. 原因切り分けリスト
   - 外部API待ち（モック/スタブの不足） → モック化・スタブ化
   - DBの非効率（N+1・未限定クエリ） → クエリ最適化 / fixture 変更
   - 大量データ生成 → テストデータを軽量化
   - 時間依存処理（sleep 等） → 時間をモック/短縮
   - 並列実行の競合 → シリアル化 or 環境分離
4. 対応案
   - 直接修正して高速化
   - 修正困難なら `:slow` タグで CI 分離
   - 長期的対応は issue を作成して担当を割り当てる

## コマンド例
- 全体テスト（スクリプト）: `scripts/run-test-rails.sh`
- RSpec プロファイル: `bundle exec rspec --profile`
- 個別実行: `bundle exec rspec spec/models/foo_spec.rb:42`

