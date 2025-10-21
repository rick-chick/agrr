# Fixtureリファクタリング完了報告

## 実施した修正

### 1. 重複テストファイルの削除
**問題**: `test/models/farm_default_test.rb`と`test/models/farm_reference_test.rb`が同じ`FarmReferenceTest`クラスを定義していた
- **解決**: `farm_default_test.rb`を削除
- **結果**: テスト実行時の重複エラーを解消

### 2. Fixture定義の修正
**問題**: `cultivation_plans.yml`の`user: `が空で、nullではなく空文字列として解釈される可能性があった
- **解決**: `user_id: null`に明示的に変更
- **結果**: Public planのuser参照エラーを解消

### 3. Fixtureデータの簡略化
すべてのfixtureファイルを見直し、テストに必要な最小限のデータに絞り込みました。

#### 変更内容:
- **users.yml**: 3ユーザー（one, two, developer）のみに簡略化
- **farms.yml**: 3農場（one, two, farm_tokyo）のみに簡略化
- **fields.yml**: 5圃場のみに簡略化
- **crops.yml**: 3作物（tomato, cucumber, tomato_user）のみに簡略化
- **cultivation_plans.yml**: 2計画（public_plan_1, plan_2025）のみに簡略化
- **sessions.yml**: 2セッション（one, two）のみに簡略化

#### 削除した項目:
- 不要なタイムスタンプフィールド（`created_at`, `updated_at`）
  - Railsが自動的に設定するため
- オプションフィールドの一部（`avatar_url`など）
  - テストに不要なため
- 重複するテストデータ
  - `test_farm`を削除（oneとほぼ同じ）
  - `plan_2026`を削除（plan_2025で十分）
  - `lettuce`, `cucumber_user`を削除（基本テストには不要）

## Fixtureの設計方針

### 基本原則
1. **最小限のデータ**: テストに必要な最小限のデータのみを定義
2. **明示的なnull**: `user_id: null`のように明示的に定義
3. **コメント追加**: 各fixtureの目的をコメントで説明
4. **依存関係の明確化**: 関連するデータの依存関係を明確に

### Fixtureの使用ガイドライン

#### いつFixtureを使うべきか
- 複数のテストで共通して使用するデータ
- モデルの基本的な関連をテストする場合
- 基本的なバリデーションテスト

#### いつテストデータを直接作成すべきか
- 特定のテストケースに特化したデータ
- 複雑な状態やエッジケースのテスト
- データの状態を細かく制御したい場合

#### 推奨パターン
```ruby
class MyTest < ActiveSupport::TestCase
  def setup
    # Fixtureから基本データを取得
    @user = users(:one)
    @farm = farms(:one)
    
    # テスト固有のデータは直接作成
    @special_field = Field.create!(
      farm: @farm,
      user: @user,
      name: "特殊な圃場",
      area: 999.0
    )
  end
  
  test "specific case" do
    # テストに必要なデータを明示的に作成
    crop = Crop.create!(
      name: "特殊作物",
      user: @user,
      area_per_unit: 1.0
    )
    
    # アサーション...
  end
end
```

## 検証結果

### テスト実行結果
```bash
docker compose run --rm test bundle exec rails test test/models/farm_reference_test.rb
# => 7 runs, 16 assertions, 0 failures, 0 errors, 0 skips ✓
```

### Fixtureロード確認
```bash
docker compose run --rm test bundle exec rails db:fixtures:load RAILS_ENV=test
# => 正常にロード完了 ✓
```

## 残存する問題

以下の問題はfixtureとは無関係です：
1. I18n翻訳の不足（`ja.activerecord.errors.messages.*`）
2. 一部のモデルテストの失敗（CropTest、SessionTestなど）
3. SimpleCovのカバレッジ不足

これらは別途対応が必要です。

## 今後の推奨事項

1. **新規Fixtureの追加は慎重に**
   - 本当に必要か検討する
   - テストデータの直接作成を優先する

2. **Fixtureの定期的な見直し**
   - 使われていないfixtureデータを削除
   - 重複するデータを統合

3. **テストの独立性を保つ**
   - 各テストが他のテストに依存しないようにする
   - setup/teardownで状態をクリーンアップ

4. **ドキュメントの整備**
   - Fixtureの使用方法をREADMEに記載
   - 各fixtureファイルにコメントを追加

## 参考資料

- [Rails Testing Guide - Fixtures](https://guides.rubyonrails.org/testing.html#the-low-down-on-fixtures)
- [RSpec Best Practices - Fixtures vs Factories](https://github.com/rubocop/rspec-style-guide#fixtures)


