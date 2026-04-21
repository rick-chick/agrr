# Private Plans 通年計画 実装計画書（優先度付き）

## 📋 概要

本ドキュメントは、`private_plans_annual_planning_design.md`、`private_plans_annual_planning_design_verification.md`、`private_plans_annual_planning_design_additional_considerations.md`を基に、優先度を明確にした実装計画をまとめたものです。

## 🎯 実装の全体像

年度ベースの計画管理から、農場ベースの通年計画管理への移行。既存データとの後方互換性を保ちながら、段階的に実装を進めます。

## 📊 優先度定義

- **🔴 最優先（Critical）**: データ整合性・基盤機能に直結。他に依存されるため最初に実装
- **🟠 高（High）**: 主要機能の実装に必要。Phase 1完了後に実装
- **🟡 中（Medium）**: 機能完成に必要だが、段階的に実装可能
- **🟢 低（Low）**: UI改善・最適化。主要機能完成後に実装

---

## 🔴 最優先（Phase 1: データモデル基盤）

### 1.1 マイグレーション実装 🔴

**優先度**: 最優先  
**依存関係**: なし  
**所要時間**: 2-3時間

#### タスク
- [ ] 既存データの重複チェックスクリプト作成・実行
  - 同じ`farm_id × user_id`で複数の`plan_year`が存在するか確認
  - 重複がある場合はエラーを出してマイグレーションを中止
- [ ] `plan_year`をnullableに変更
- [ ] 既存の一意制約を削除（`index_cultivation_plans_on_farm_user_year_unique`）
- [ ] 新しい一意制約を追加（`farm_id × user_id`、`plan_type = 'private'`の条件付き）
- [ ] ロールバック処理の実装

#### 注意事項
- **重要**: マイグレーション前に必ず重複チェックを実施
- 既存データの`plan_year`は保持（後方互換性）
- 本番環境では事前にバックアップを取得

#### 関連ファイル
- `db/migrate/YYYYMMDDHHMMSS_change_private_plans_to_annual_planning.rb`

---

### 1.2 CultivationPlanモデルの変更 🔴

**優先度**: 最優先  
**依存関係**: 1.1完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] `plan_year`の必須バリデーションを削除（private計画でも）
- [ ] 一意制約のスコープを変更（`farm_id × user_id`のみ）
- [ ] `display_name`メソッドの修正
  - `plan_year`が`null`の場合は計画期間を表示
  - 既存データ（`plan_year`あり）は従来通り表示
- [ ] `planning_start_date`と`planning_end_date`の必須バリデーションを維持
- [ ] `calculate_planning_dates`メソッドは後方互換性のため残す

#### コード例
```ruby
# display_nameメソッドの修正
def display_name
  if plan_type_private?
    name = plan_name.presence || I18n.t('models.cultivation_plan.default_plan_name')
    if plan_year.present?
      "#{name} (#{plan_year})"
    elsif planning_start_date && planning_end_date
      "#{name} (#{planning_start_date.year}〜#{planning_end_date.year})"
    else
      name
    end
  else
    I18n.t('models.cultivation_plan.public_plan_name')
  end
end
```

#### 関連ファイル
- `app/models/cultivation_plan.rb`

---

### 1.3 モデルテスト 🔴

**優先度**: 最優先  
**依存関係**: 1.2完了後  
**所要時間**: 2-3時間

#### タスク
- [ ] `plan_year`が`null`でもバリデーションが通ることを確認
- [ ] 一意制約のテスト更新
  - 同じ`farm_id × user_id`で複数の計画を作成できないことを確認
  - 異なる`farm_id`または`user_id`では作成可能なことを確認
- [ ] 通年計画（`plan_year`が`null`）のテストを追加
- [ ] 既存データの互換性テスト（`plan_year`ありの計画が正常に動作することを確認）
- [ ] `display_name`メソッドのテスト追加

#### 関連ファイル
- `test/models/cultivation_plan_test.rb`
- `spec/models/cultivation_plan_spec.rb`（RSpecの場合）

---

### 1.4 データベースインデックスの整理 🔴

**優先度**: 最優先  
**依存関係**: 1.1完了後  
**所要時間**: 1時間

#### タスク
- [ ] `plan_year`を含むインデックスの確認
  - `index_cultivation_plans_on_user_plan_name_year`
  - `index_cultivation_plans_on_user_id_and_plan_year`
- [ ] 不要なインデックスの削除または条件更新
- [ ] パフォーマンステスト（インデックス削除後のクエリ速度確認）

#### 関連ファイル
- `db/schema.rb`
- マイグレーションファイル

---

## 🟠 高優先度（Phase 2: ビジネスロジック層）

### 2.0 PlanSaveServiceの変更 🟠

**優先度**: 高  
**依存関係**: Phase 1完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] `find_existing_private_plan`メソッドの変更
  - `plan_year`を除外して検索
  - `farm_id`と`user_id`のみで検索
- [ ] `calculate_plan_year_from_cultivations`メソッドの扱い
  - 通年計画の場合、`plan_year`を`null`にする
  - 参照計画が通年計画の場合は、`plan_year`を設定しない
  - `planning_start_date`と`planning_end_date`は作付け期間から計算

#### コード例
```ruby
def find_existing_private_plan(farm)
  @user.cultivation_plans.where(plan_type: 'private', farm: farm).first
end
```

#### 関連ファイル
- `app/services/plan_save_service.rb`

---

### 2.1 PlansControllerの変更 🟠

**優先度**: 高  
**依存関係**: Phase 1完了後  
**所要時間**: 3-4時間

#### タスク
- [ ] セッション管理の変更
  - セッションから`plan_year`を削除
  - `validate_session_data`で`plan_year`のチェックを削除
  - `find_existing_plan`で`plan_year`を除外して検索
- [ ] `index`: 年度別から農場別に変更
- [ ] `new`: 年度選択を削除、農場選択のみ
- [ ] `select_crop`: `plan_year`パラメータを削除
- [ ] `create`: `plan_year`を使わずに計画作成
- [ ] `build_creator_params`: `plan_year`を使わずに`planning_start_date`と`planning_end_date`を設定
- [ ] `copy`: 通年計画の場合のコピー機能の扱いを決定
  - オプション1: コピー機能を無効化
  - オプション2: 計画期間を延長する機能に変更
  - オプション3: 計画を複製する機能に変更

#### 関連ファイル
- `app/controllers/plans_controller.rb`

---

### 2.2 Presenter変更 🟠

**優先度**: 高  
**依存関係**: 2.1完了後  
**所要時間**: 2-3時間

#### タスク
- [ ] `Plans::IndexPresenter`
  - `plans_by_year`メソッドを`plans_by_farm`に変更
  - 農場別にグループ化
  - `plan_year`が`null`の計画も正しく表示
- [ ] `Plans::NewPresenter`
  - 年度関連のメソッドを削除（`available_years`など）
- [ ] `Plans::SelectCropPresenter`
  - `plan_year`パラメータを削除またはオプショナル化
- [ ] `Plans::ShowPresenter`
  - 表示範囲選択機能を追加（将来的に使用）

#### 関連ファイル
- `app/presenters/plans/index_presenter.rb`
- `app/presenters/plans/new_presenter.rb`
- `app/presenters/plans/select_crop_presenter.rb`
- `app/presenters/plans/show_presenter.rb`

---

### 2.3 PlanningSchedulesControllerの変更 🟠

**優先度**: 高  
**依存関係**: Phase 1完了後  
**所要時間**: 2-3時間

#### タスク
- [ ] `plan_year`によるフィルタリングを`planning_start_date`/`planning_end_date`ベースに変更
- [ ] `field_cultivation.start_date.year == plan.plan_year`の重複防止ロジックを変更
- [ ] 通年計画（`plan_year`が`null`）の対応
  - `plan_year`が`null`の場合は期間ベースで判定
- [ ] 既存データ（`plan_year`あり）との互換性を保つ

#### 関連ファイル
- `app/controllers/planning_schedules_controller.rb`

---

### 2.4 PlanCopierの変更 🟠

**優先度**: 高  
**依存関係**: Phase 1完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] 通年計画の場合のコピー機能の扱いを決定
  - オプション1: コピー機能を無効化（通年計画では不要）
  - オプション2: 計画期間を延長する機能に変更
  - オプション3: 計画を複製する機能に変更（期間は同じ）
- [ ] `copy`メソッドで`plan_year`が`null`の場合のエラーハンドリング
- [ ] 既存データ（`plan_year`あり）のコピー機能は維持

#### 関連ファイル
- `app/controllers/plans_controller.rb`（`copy`メソッド）
- `lib/domain/cultivation_plan/interactors/plan_copier.rb` / `Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year`

---

### 2.5 APIレスポンスの変更 🟠

**優先度**: 高  
**依存関係**: Phase 1完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] `CultivationPlanApi#data`で`plan_year`が`null`の場合の処理を追加
- [ ] フロントエンドが`plan_year`に依存している場合は、後方互換性のため`null`を返すか、期間情報を返す
- [ ] フロントエンドのコードを確認し、`plan_year`の使用箇所を修正（必要に応じて）

#### 関連ファイル
- `app/controllers/concerns/cultivation_plan_api.rb`
- フロントエンドのJavaScriptファイル

---

### 2.6 コントローラー・Presenterテスト 🟠

**優先度**: 高  
**依存関係**: 2.1, 2.2完了後  
**所要時間**: 3-4時間

#### タスク
- [ ] コントローラーのテスト
  - 年度選択なしで計画を作成できることを確認
  - 農場別に一覧が表示されることを確認
  - 既存の計画が正しく表示されることを確認
  - セッション管理の変更を反映
- [ ] Presenterのテスト
  - `plans_by_farm`メソッドのテスト
  - `plan_year`が`null`の計画も正しく表示されることを確認

#### 関連ファイル
- `test/controllers/plans_controller_test.rb`
- `test/presenters/plans/index_presenter_test.rb`
- その他のPresenterテスト

---

## 🟡 中優先度（Phase 3: ビュー層）

### 3.1 ビュー変更 🟡

**優先度**: 中  
**依存関係**: Phase 2完了後  
**所要時間**: 3-4時間

#### タスク
- [ ] `plans/index.html.erb`
  - 年度別表示を農場別表示に変更
  - 計画期間を表示（`planning_start_date 〜 planning_end_date`）
  - `plan_year`が`null`の計画も正しく表示
- [ ] `plans/new.html.erb`
  - 年度選択UIを削除
  - 農場選択のみ表示
  - 計画名入力フィールドを追加（オプショナル、デフォルトは農場名）
- [ ] `plans/show.html.erb`
  - 開始日・終了日の選択UIを追加（Phase 4で使用）
  - 選択した期間をガントチャートに渡す

#### 関連ファイル
- `app/views/plans/index.html.erb`
- `app/views/plans/new.html.erb`
- `app/views/plans/show.html.erb`

---

### 3.2 ローカライズファイルの更新 🟡

**優先度**: 中  
**依存関係**: Phase 2完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] 全てのローカライズファイルを確認
  - `config/locales/views/plans.ja.yml`
  - `config/locales/views/plans.us.yml`
  - `config/locales/views/plans.in.yml`
  - その他の言語ファイル
- [ ] 年度関連のメッセージを期間ベースに変更するか、条件分岐を追加
- [ ] 計画コピー時のメッセージを期間ベースに変更

#### 関連ファイル
- `config/locales/views/plans.*.yml`

---

## 🟢 低優先度（Phase 4: ガントチャート機能）

### 4.1 ガントチャートの表示範囲制御 🟢

**優先度**: 低  
**依存関係**: Phase 3完了後  
**所要時間**: 4-6時間

#### タスク
- [ ] `custom_gantt_chart.js`: 表示範囲の制御機能を追加
  - 開始日・終了日の選択UI
  - 選択した期間のみ表示
  - 枠外の作付の処理（表示範囲内のみ表示、移動不可）
- [ ] `crop_palette_drag.js`: ドロップ時の範囲チェック
- [ ] ドラッグアンドドロップの制限ロジック
  - 表示範囲内の作付: 移動可能
  - 枠外にかかる作付: 移動不可（表示範囲内のみ表示）

#### 実装ロジック
```javascript
// 表示範囲の設定
window.ganttState.displayStartDate = selectedStartDate;
window.ganttState.displayEndDate = selectedEndDate;

// 作付の表示判定
function shouldDisplayCultivation(cultivation) {
  const { start_date, completion_date } = cultivation;
  const { displayStartDate, displayEndDate } = window.ganttState;
  
  // 表示範囲と重複しているか
  return !(completion_date < displayStartDate || start_date > displayEndDate);
}

// 移動制限の判定
function isMovable(cultivation) {
  const { start_date, completion_date } = cultivation;
  const { displayStartDate, displayEndDate } = window.ganttState;
  
  // 表示範囲内に完全に収まっているか
  return start_date >= displayStartDate && completion_date <= displayEndDate;
}
```

#### 関連ファイル
- `app/assets/javascripts/custom_gantt_chart.js`
- `app/assets/javascripts/crop_palette_drag.js`

---

### 4.2 API変更 🟢

**優先度**: 低  
**依存関係**: 4.1完了後  
**所要時間**: 1-2時間

#### タスク
- [ ] `Api::V1::Plans::CultivationPlansController#data`: 表示範囲パラメータを受け取る
- [ ] 表示範囲内の作付のみ返す（または全データを返してフロントでフィルタ）
- [ ] パフォーマンスを考慮した実装（大量データの場合）

#### 関連ファイル
- `app/controllers/api/v1/plans/cultivation_plans_controller.rb`

---

### 4.3 統合・システムテスト 🟢

**優先度**: 低  
**依存関係**: Phase 4完了後  
**所要時間**: 3-4時間

#### タスク
- [ ] 統合テスト
  - 新規作成フローが正常に動作することを確認
  - 表示範囲の選択がガントチャートに反映されることを確認
  - 枠外の作付が正しく表示されることを確認
- [ ] システムテスト
  - ユーザーが計画を作成・編集できることを確認
  - 表示範囲の選択が正常に動作することを確認
  - ドラッグアンドドロップの制限が正常に動作することを確認

#### 関連ファイル
- `test/integration/plans_test.rb`
- `test/system/plans_test.rb`

---

## 📅 実装スケジュール（推奨）

### Week 1: 基盤実装
- Day 1-2: Phase 1.1 マイグレーション実装
- Day 3: Phase 1.2 モデル変更
- Day 4: Phase 1.3 モデルテスト
- Day 5: Phase 1.4 インデックス整理

### Week 2: ビジネスロジック層
- Day 1: Phase 2.0 PlanSaveService変更
- Day 2-3: Phase 2.1 PlansController変更
- Day 4: Phase 2.2 Presenter変更
- Day 5: Phase 2.3 PlanningSchedulesController変更

### Week 3: ビジネスロジック層（続き）
- Day 1: Phase 2.4 PlanCopier変更
- Day 2: Phase 2.5 APIレスポンス変更
- Day 3-4: Phase 2.6 コントローラー・Presenterテスト

### Week 4: ビュー層
- Day 1-2: Phase 3.1 ビュー変更
- Day 3: Phase 3.2 ローカライズファイル更新

### Week 5: ガントチャート機能
- Day 1-3: Phase 4.1 ガントチャートの表示範囲制御
- Day 4: Phase 4.2 API変更
- Day 5: Phase 4.3 統合・システムテスト

---

## ⚠️ リスク管理

### 高リスク項目

1. **マイグレーション時のデータ整合性**
   - リスク: 既存データで重複が発生する可能性
   - 対策: マイグレーション前に必ず重複チェックを実施

2. **既存データと新規データの混在**
   - リスク: 表示や検索ロジックが複雑になる
   - 対策: 既存データの`plan_year`を保持し、新規データは`null`にする方針を維持

3. **PlanningSchedulesControllerへの影響**
   - リスク: `plan_year`に強く依存しているため、変更範囲が大きい
   - 対策: 段階的に実装し、既存データとの互換性を保つ

### 中リスク項目

1. **フロントエンドのJavaScript依存**
   - リスク: `plan_year`を期待しているコードがある可能性
   - 対策: APIレスポンスで`null`を返し、フロントエンドで対応

2. **テストコードの更新漏れ**
   - リスク: 一部のテストが更新されず、後で問題が発覚
   - 対策: 各フェーズで必ずテストを更新

---

## ✅ チェックリスト

### Phase 1完了時
- [ ] マイグレーションが正常に実行できる
- [ ] 既存データが正常に表示される
- [ ] 新規データ（`plan_year`が`null`）が正常に作成できる
- [ ] 一意制約が正しく機能する
- [ ] モデルテストが全て通過する

### Phase 2完了時
- [ ] 年度選択なしで計画を作成できる
- [ ] 農場別に一覧が表示される
- [ ] 既存の計画が正しく表示される
- [ ] PlanningSchedulesControllerが正常に動作する
- [ ] コントローラー・Presenterテストが全て通過する

### Phase 3完了時
- [ ] ビューが正しく表示される
- [ ] 年度選択UIが削除されている
- [ ] 農場別表示が正しく動作する
- [ ] ローカライズメッセージが正しく表示される

### Phase 4完了時
- [ ] ガントチャートの表示範囲制御が正常に動作する
- [ ] 枠外の作付が正しく表示される
- [ ] ドラッグアンドドロップの制限が正常に動作する
- [ ] 統合・システムテストが全て通過する

---

## 📝 備考

- 各フェーズで必ずテストを実施し、問題がなければ次のフェーズに進む
- 本番環境へのデプロイ前に、ステージング環境で十分なテストを実施
- 既存データとの後方互換性を常に意識する
- 不明な点や問題が発生した場合は、設計書を参照し、必要に応じて設計を見直す

