# No Allocation Candidates Error 処理

## 概要

作付け計画の最適化時に「No valid allocation candidates could be generated.」エラーが発生した場合の処理を実装しました。このエラーは、AGRR CLIが作付け計画の候補を生成できなかった場合に発生します。

## 実装内容

### 1. 専用例外クラスの追加

`app/gateways/agrr/base_gateway.rb` に `NoAllocationCandidatesError` 例外クラスを追加しました。

```ruby
class NoAllocationCandidatesError < StandardError; end
```

### 2. エラーメッセージの検知

`execute_command` メソッドで、AGRR CLIからのエラーメッセージを検知して専用例外を投げるようにしました。

- stdoutが「No valid allocation candidates could be generated」を含む場合
- stderrが「No valid allocation candidates could be generated」を含む場合

### 3. ユーザーフレンドリーなエラーメッセージ

`CultivationPlanOptimizer` で `NoAllocationCandidatesError` を個別にキャッチして、ユーザーに分かりやすいエラーメッセージを返します。

エラーメッセージには以下の情報が含まれます：

1. **計画期間内に作物が成熟しない**
   - 対処法：計画期間を延長するか、より短期間で収穫できる作物を選択

2. **圃場の面積が不足している**
   - 対処法：圃場の面積を増やすか、作物の数を減らす

3. **気象条件が適していない**
   - 対処法：選択した作物が気象条件に適していない可能性があるため、別の作物を試す

4. **作物の収益設定が適切でない**
   - 対処法：作物の収益設定（revenue_per_area）を確認

5. **技術的な詳細** 
   - AGRR CLIから返された元のエラーメッセージ

## エラーメッセージ例

```
作付け計画の候補を生成できませんでした。以下の可能性があります：

1. 計画期間内に作物が成熟しない
   → 計画期間を延長するか、より短期間で収穫できる作物を選択してください

2. 圃場の面積が不足している
   → 圃場の面積を増やすか、作物の数を減らしてください

3. 気象条件が適していない
   → 選択した作物が気象条件に適していない可能性があります。別の作物を試してください

4. 作物の収益設定が適切でない
   → 作物の収益設定（revenue_per_area）を確認してください

技術的な詳細: No valid allocation candidates could be generated. ...
```

## テスト

`test/services/cultivation_plan_optimizer_test.rb` に以下のテストを追加しました：

- `test_should_handle_no_allocation_candidates_error_with_user_friendly_message`

このテストでは、AllocationGatewayがNoAllocationCandidatesErrorを投げた場合に、適切なエラーメッセージがユーザーに表示されることを確認しています。

## 関連ファイル

- `app/gateways/agrr/base_gateway.rb` - 専用例外クラスとエラー検知
- `app/services/cultivation_plan_optimizer.rb` - エラーハンドリングとユーザーフレンドリーメッセージ
- `test/services/cultivation_plan_optimizer_test.rb` - テスト

## 使用方法

作付け計画を実行すると、エラーが発生した場合には `cultivation_plan.error_message` にユーザーフレンドリーなエラーメッセージが設定されます。

```ruby
cultivation_plan = CultivationPlan.find(id)
optimizer = CultivationPlanOptimizer.new(cultivation_plan)

if optimizer.call
  # 成功
else
  # 失敗: cultivation_plan.error_message にエラーメッセージが設定される
  puts cultivation_plan.error_message
end
```

