# Test Directory

## ⚠️ IMPORTANT: Testing Guidelines

**すべてのテストは [docs/TESTING_GUIDELINES.md](../docs/TESTING_GUIDELINES.md) に従って作成してください。**

## テスト要件（必須）

### モデルレベルのテスト（必須）
- 直接データベース操作での制限テスト
- 参照レコードの除外ルールのテスト
- 更新シナリオのテスト

### 統合テスト（必須）
- サービスオブジェクトの統合テスト
- コントローラーアクションの統合テスト
- クロスモデルバリデーションのテスト

### リソース制限テスト（必須）
- リソース上限のテスト
- 境界値テスト（4件、5件など）
- エラーメッセージのテスト

## テスト原則

- ❌ **パッチは使わない** - Clean Architectureなので依存性注入を使用
- ✅ **モックはconftestに書く** - テストファイルではなくconftestで管理
- ✅ **テストファースト** - 実装前にテストを書く
- ✅ **異常系はエラーを上げる** - フォールバックではなくエラー処理

## テスト実行

```bash
# 全テスト実行
docker compose run --rm test bundle exec rails test

# 特定のテストファイル
docker compose run --rm test bundle exec rails test test/models/farm_test.rb

# 特定のテストメソッド
docker compose run --rm test bundle exec rails test test/models/farm_test.rb -n test_should_prevent_creating_5th_farm

# 統合テストのみ
docker compose run --rm test bundle exec rails test test/integration/
```

## テストファイル構成

```
test/
├── models/          # モデルレベルのテスト（必須）
├── integration/     # 統合テスト（必須）
├── controllers/     # コントローラーテスト
├── services/        # サービスオブジェクトのテスト（必須）
├── system/          # システムテスト
├── factories/       # FactoryBotのファクトリー
├── fixtures/        # フィクスチャ（可能な限りFactoryBotを使用）
└── support/         # テストサポートファイル
```

詳細は [docs/TESTING_GUIDELINES.md](../docs/TESTING_GUIDELINES.md) を参照してください。

