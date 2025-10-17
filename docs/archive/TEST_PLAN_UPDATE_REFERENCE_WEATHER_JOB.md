# UpdateReferenceWeatherDataJob 包括的テスト計画書

## プロジェクト状況分析

### 現状の課題
1. **実行頻度**: 毎日1回（午前3時）のみ
2. **影響範囲**: 全参照農場47件の天気データ
3. **エラー検知**: ログのみ（外部監視なし）
4. **リカバリー**: 自動リトライなし
5. **通知**: なし（人知れず失敗する可能性）

### リスク評価
- **高リスク**: 全参照農場のデータ更新が止まる
- **中リスク**: 一部農場のみ失敗（部分的なデータ欠損）
- **低リスク**: 既存データがあるため一時的な失敗は許容可能

---

## テスト戦略

### 1. 単体テスト（Unit Tests）

#### 1.1 正常系テスト
- [x] 基本動作（参照農場の天気データ更新ジョブをエンキュー）
- [x] 引数の正確性（farm_id、latitude、longitude、start_date、end_date）
- [x] 日付範囲（7日前〜今日）
- [x] API負荷軽減（1秒間隔）
- [ ] 実行時間の計測（パフォーマンステスト）

#### 1.2 異常系テスト（追加必要）
- [ ] **参照農場が0件の場合**
  - 期待: 正常終了、0件のジョブをエンキュー
  
- [ ] **参照農場が1件の場合**
  - 期待: 1件のジョブをエンキュー
  
- [ ] **参照農場が多数（100件）の場合**
  - 期待: すべてのジョブがエンキューされる
  - タイムアウトしない
  
- [ ] **座標がnilの参照農場が混在**
  - 期待: 有効な農場のみジョブをエンキュー
  
- [ ] **緯度経度が不正な値**
  - 期待: バリデーションエラー
  
- [ ] **データベース接続エラー**
  - 期待: リトライまたは適切なエラーハンドリング

#### 1.3 境界値テスト
- [ ] **日付の境界**
  - Date.today が日付変更直後
  - Date.today が日付変更直前
  - うるう年の2月29日
  
- [ ] **農場数の境界**
  - 0件、1件、47件、100件、1000件

#### 1.4 依存関係テスト
- [ ] **FetchWeatherDataJobへの依存**
  - FetchWeatherDataJobが正しくエンキューされる
  - 引数が正しく渡される
  - farm_idが正しく設定される
  
- [ ] **Farm.referenceスコープへの依存**
  - is_reference=trueのみ取得
  - 座標がnilは除外
  - 削除済みは除外

---

### 2. 統合テスト（Integration Tests）

#### 2.1 エンドツーエンドテスト（追加必要）
- [ ] **完全フロー**
  ```ruby
  # 1. ジョブ実行
  # 2. 47件のFetchWeatherDataJobがエンキュー
  # 3. すべてのジョブが実行される
  # 4. WeatherDataが更新される
  # 5. ログが出力される
  ```

#### 2.2 並行実行テスト
- [ ] **複数のUpdateReferenceWeatherDataJobが同時実行**
  - 期待: データの整合性が保たれる
  - 期待: 重複したジョブがエンキューされない

#### 2.3 リトライテスト
- [ ] **FetchWeatherDataJobが失敗した場合**
  - 期待: リトライされる（FetchWeatherDataJobのリトライ機能）
  - 期待: 他の農場のジョブは影響を受けない

---

### 3. エラーハンドリングテスト（現在欠落）

#### 3.1 例外処理
**現状**: エラーハンドリングが実装されていない

**追加必要な実装**:
```ruby
class UpdateReferenceWeatherDataJob < ApplicationJob
  queue_as :default
  
  # ネットワークエラー等でリトライ
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # データベース接続エラーでリトライ
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 10.seconds, attempts: 5
  
  # レコードが見つからない場合は破棄（リトライしない）
  discard_on ActiveRecord::RecordNotFound
  
  def perform
    # ... existing code ...
  rescue StandardError => e
    Rails.logger.error "❌ UpdateReferenceWeatherDataJob failed: #{e.message}"
    Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
    # 管理者に通知（将来実装）
    # AdminNotifier.job_failed(self.class.name, e).deliver_later
    raise # リトライのために再raiseする
  end
end
```

**テスト項目**:
- [ ] StandardErrorでリトライされる
- [ ] 3回までリトライする
- [ ] 指数バックオフが適用される
- [ ] ActiveRecord::RecordNotFoundで破棄される
- [ ] ログが出力される

#### 3.2 タイムアウトテスト
- [ ] **ジョブ実行が長時間かかる場合**
  - 現状: タイムアウト設定なし
  - 追加必要: `timeout` 設定

---

### 4. パフォーマンステスト

#### 4.1 実行時間
- [ ] **47件の農場で実行時間を計測**
  - 期待: 50秒以内（47件 × 1秒 + オーバーヘッド）
  
- [ ] **100件の農場で実行時間を計測**
  - 期待: スケールする（線形増加）

#### 4.2 メモリ使用量
- [ ] **メモリリーク検証**
  - 期待: メモリ使用量が安定している

#### 4.3 データベース負荷
- [ ] **クエリ数の計測**
  - 期待: N+1クエリが発生しない
  - 現状: `Farm.reference.where.not(...)` → 1クエリ（OK）

---

### 5. 監視・アラートテスト（現在欠落）

#### 5.1 ログ監視
**現状**: 基本的なログは実装済み
- ✅ 開始ログ
- ✅ 農場数ログ
- ✅ 取得期間ログ
- ✅ 完了ログ

**追加必要**:
- [ ] エラー発生時の詳細ログ
- [ ] 実行時間ログ
- [ ] メトリクスログ（成功数/失敗数）

#### 5.2 アラート（将来実装）
- [ ] **ジョブ失敗時のアラート**
  - Slack通知
  - メール通知
  - 管理画面での表示

#### 5.3 健全性チェック
- [ ] **定期実行の健全性チェック**
  - 24時間以内に実行されたか
  - すべての参照農場が更新されたか
  - データの鮮度チェック

---

### 6. 回復性テスト（Resilience Tests）

#### 6.1 部分失敗からの回復
- [ ] **一部の農場のジョブが失敗した場合**
  - 期待: 他の農場は正常に更新される
  - 期待: 翌日再実行で失敗した農場も更新される

#### 6.2 完全失敗からの回復
- [ ] **すべてのジョブが失敗した場合**
  - 期待: 翌日再実行で回復する
  - 期待: データの整合性が保たれる

#### 6.3 手動リカバリー手順
**ドキュメント化必要**:
```bash
# 特定の農場のみ更新
docker compose exec web rails runner "
  farm = Farm.find_by(name: '北海道')
  FetchWeatherDataJob.perform_later(
    farm_id: farm.id,
    latitude: farm.latitude,
    longitude: farm.longitude,
    start_date: Date.today - 7.days,
    end_date: Date.today
  )
"

# すべての参照農場を再更新
docker compose exec web rails runner "UpdateReferenceWeatherDataJob.perform_now"
```

---

### 7. セキュリティテスト

#### 7.1 権限テスト
- [ ] **アノニマスユーザー以外の参照農場は処理されない**
  - 現状: Farm.referenceスコープで自動フィルタ（OK）

#### 7.2 インジェクション対策
- [ ] **SQLインジェクション**
  - 現状: ActiveRecordのスコープ使用（OK）

---

### 8. 回帰テスト

#### 8.1 既存機能への影響
- [ ] **通常の農場作成時の天気データ取得に影響しない**
- [ ] **FetchWeatherDataJobの動作に影響しない**
- [ ] **Farmモデルのバリデーションに影響しない**

---

## テストカバレッジ目標

### 現状
- UpdateReferenceWeatherDataJob: **基本テストのみ実装**
- テストケース: 5件
- カバレッジ: **約40%（推定）**

### 目標
- UpdateReferenceWeatherDataJob: **包括的テスト実装**
- テストケース: **25件以上**
- カバレッジ: **95%以上**
- エラーパス: **100%**

---

## 優先順位

### P0（緊急 - 即座に実装）
1. ✅ 基本動作テスト
2. **❌ エラーハンドリングの実装とテスト**
3. **❌ リトライ機能の実装とテスト**
4. **❌ 部分失敗テスト**

### P1（高優先 - 1週間以内）
5. **❌ タイムアウトテスト**
6. **❌ パフォーマンステスト**
7. **❌ 境界値テスト**
8. **❌ ログ強化**

### P2（中優先 - 2週間以内）
9. **❌ 並行実行テスト**
10. **❌ 健全性チェック機能**
11. **❌ 手動リカバリー手順書**

### P3（低優先 - 1ヶ月以内）
12. **❌ アラート機能実装**
13. **❌ メトリクス収集**
14. **❌ 監視ダッシュボード**

---

## テスト実行方法

### 単体テスト
```bash
# 特定のテストのみ
docker compose run --rm test bundle exec rails test test/jobs/update_reference_weather_data_job_test.rb

# カバレッジ確認
open coverage/index.html
```

### 統合テスト
```bash
# すべてのジョブテスト
docker compose run --rm test bundle exec rails test test/jobs/

# 関連するすべてのテスト
docker compose run --rm test bundle exec rails test test/jobs/ test/models/farm_test.rb
```

### 手動テスト
```bash
# 開発環境で実行
docker compose exec web rails runner "UpdateReferenceWeatherDataJob.perform_now"

# ログ確認
docker compose exec web tail -f log/development.log | grep UpdateReferenceWeatherDataJob

# ジョブ状態確認
docker compose exec web rails runner "
  puts 'Enqueued jobs:'
  SolidQueue::Job.where(finished_at: nil, class_name: 'FetchWeatherDataJob').each { |j| puts j.inspect }
"
```

---

## テストデータ準備

### Fixture
```yaml
# test/fixtures/farms.yml に追加
reference_farm_1:
  user: anonymous
  name: テスト参照農場1
  latitude: 35.6895
  longitude: 139.6917
  is_reference: true
  weather_data_status: completed

reference_farm_2:
  user: anonymous
  name: テスト参照農場2
  latitude: 43.0642
  longitude: 141.3469
  is_reference: true
  weather_data_status: completed

reference_farm_no_coords:
  user: anonymous
  name: 座標なし参照農場
  latitude: null
  longitude: null
  is_reference: true
```

### モックデータ
```ruby
# test/support/agrr_mock_helper.rb を活用
# 既存のモックを使用してAPI呼び出しを高速化
```

---

## 品質基準

### 合格基準
- [ ] すべてのP0テストが実装され、パスする
- [ ] カバレッジが95%以上
- [ ] エラーハンドリングが完全
- [ ] ドキュメントが整備されている

### レビュー項目
- [ ] テストコードの可読性
- [ ] テストの独立性（他のテストに依存しない）
- [ ] テストの再現性（何度実行しても同じ結果）
- [ ] テストの実行時間（5秒以内）

---

## 継続的改善

### 定期レビュー
- **週次**: テスト実行結果の確認
- **月次**: カバレッジレポートのレビュー
- **四半期**: テスト戦略の見直し

### メトリクス
- テスト実行時間
- テストカバレッジ
- エラー発生率
- 平均復旧時間（MTTR）

---

## 付録

### 関連ドキュメント
- `ARCHITECTURE.md` - プロジェクトアーキテクチャ
- `test/jobs/fetch_weather_data_job_test.rb` - 既存のジョブテスト
- `app/jobs/fetch_weather_data_job.rb` - 依存ジョブ

### 参考リンク
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [ActiveJob Testing Guide](https://guides.rubyonrails.org/testing.html#testing-jobs)
- [Minitest Documentation](https://github.com/minitest/minitest)

---

**作成日**: 2025-10-13  
**作成者**: AI Test Design Specialist  
**バージョン**: 1.0  
**次回レビュー**: 2025-10-20

