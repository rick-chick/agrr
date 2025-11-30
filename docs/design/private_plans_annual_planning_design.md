# Private Plans 通年計画設計書

## 📋 概要

現状のprivate_plansは年度ごとに計画を作成しているが、これを農場選択による通年の計画編集に変更する。

## 🎯 変更の目的

1. **年度の概念を廃止**: 年度ごとの計画ではなく、農場ごとの通年計画として管理
2. **柔軟な期間設定**: ユーザーが開始日・終了日を自由に選択して表示範囲を設定
3. **表示範囲制御**: 選択した期間内のみ表示し、枠外の作付は移動不可で表示範囲内のみ表示

## 📊 現状の実装

### データモデル
- `plan_year`: 必須（例: 2025）
- `planning_start_date`: plan_yearから計算（例: 2025/1/1）
- `planning_end_date`: plan_yearから計算（例: 2026/12/31、2年間）
- 一意制約: `farm_id × user_id × plan_year`

### UI/UX
- 一覧画面: 年度別にグループ化して表示
- 新規作成: 年度選択 → 農場選択 → 作物選択
- 計画表示: ガントチャートは`planning_start_date`から`planning_end_date`まで表示

## 🔄 変更後の設計

### データモデル変更

#### 1. `plan_year`の扱い
- **後方互換性のため**: `plan_year`はオプショナルに変更（既存データのため）
- **新規作成時**: `plan_year`は設定しない（または`null`）
- **既存データ**: `plan_year`が設定されている場合はそのまま使用

#### 2. 一意制約の変更
- **変更前**: `farm_id × user_id × plan_year`
- **変更後**: `farm_id × user_id`（年度を除外）
- **意味**: 1農場×1ユーザーにつき1つの計画のみ

#### 3. 計画期間の扱い
- `planning_start_date`: 必須（ユーザーが設定）
- `planning_end_date`: 必須（ユーザーが設定）
- 年度の概念はなく、自由な期間を設定可能

#### 4. マイグレーション
```ruby
# 1. plan_yearをnullableに変更
# 2. 一意制約を変更（plan_yearを除外）
# 3. 既存データのplan_yearを保持（後方互換性）
```

### UI/UX変更

#### 1. 一覧画面（`plans#index`）
- **変更前**: 年度別にグループ化
- **変更後**: 農場別にグループ化
- **表示内容**:
  - 農場名
  - 計画名（plan_name）
  - 計画期間（planning_start_date 〜 planning_end_date）
  - ステータス

#### 2. 新規作成画面（`plans#new`）
- **変更前**: 年度選択 → 農場選択
- **変更後**: 農場選択のみ
- **削除**: 年度選択UI
- **追加**: 計画名入力（オプショナル、デフォルトは農場名）

#### 3. 計画表示画面（`plans#show`）
- **追加機能**: 開始日・終了日の選択UI
  - 日付ピッカーで開始日・終了日を選択
  - 選択した期間のみガントチャートに表示
- **ガントチャート表示**:
  - 選択した期間内の作付のみ表示
  - 枠外にかかる作付は表示範囲内のみ表示（移動不可）
  - 枠外の作付はグレーアウトまたは半透明で表示

#### 4. ガントチャートのドラッグアンドドロップ制限
- **表示範囲内の作付**: 移動可能
- **枠外にかかる作付**: 移動不可（表示範囲内のみ表示）
- **移動制限の判定**:
  - 作付の開始日が表示範囲外 → 移動不可
  - 作付の終了日が表示範囲外 → 移動不可
  - 作付が表示範囲内に完全に収まっている → 移動可能

## 🏗️ 実装フェーズ

### Phase 1: データモデル変更

#### 1.1 マイグレーション
- [ ] `plan_year`をnullableに変更
- [ ] 一意制約を`farm_id × user_id`に変更（plan_yearを除外）
- [ ] 既存データの`plan_year`を保持（後方互換性）

#### 1.2 モデル変更
- [ ] `CultivationPlan`モデルのバリデーション変更
  - `plan_year`の必須バリデーションを削除（private計画でも）
  - 一意制約のスコープを変更
- [ ] `planning_start_date`と`planning_end_date`の必須バリデーションを維持
- [ ] `calculate_planning_dates`メソッドの扱いを検討（後方互換性のため残す）

#### 1.3 テスト
- [ ] モデルのバリデーションテスト
- [ ] 一意制約のテスト
- [ ] 既存データの互換性テスト

### Phase 2: コントローラー・Presenter変更

#### 2.1 `PlansController`変更
- [ ] `index`: 年度別から農場別に変更
- [ ] `new`: 年度選択を削除、農場選択のみ
- [ ] `select_crop`: `plan_year`パラメータを削除
- [ ] `create`: `plan_year`を使わずに計画作成
- [ ] `build_creator_params`: `plan_year`を使わずに`planning_start_date`と`planning_end_date`を設定

#### 2.2 Presenter変更
- [ ] `Plans::IndexPresenter`: 年度別から農場別に変更
- [ ] `Plans::NewPresenter`: 年度関連のメソッドを削除
- [ ] `Plans::SelectCropPresenter`: `plan_year`パラメータを削除
- [ ] `Plans::ShowPresenter`: 表示範囲選択機能を追加

#### 2.3 テスト
- [ ] コントローラーのテスト
- [ ] Presenterのテスト

### Phase 3: ビュー変更

#### 3.1 一覧画面（`plans/index.html.erb`）
- [ ] 年度別表示を農場別表示に変更
- [ ] 計画期間を表示（planning_start_date 〜 planning_end_date）

#### 3.2 新規作成画面（`plans/new.html.erb`）
- [ ] 年度選択UIを削除
- [ ] 農場選択のみ表示
- [ ] 計画名入力フィールドを追加（オプショナル）

#### 3.3 計画表示画面（`plans/show.html.erb`）
- [ ] 開始日・終了日の選択UIを追加
- [ ] 選択した期間をガントチャートに渡す

#### 3.4 テスト
- [ ] ビューのテスト（必要に応じて）

### Phase 4: ガントチャートの表示範囲制御

#### 4.1 JavaScript変更
- [ ] `custom_gantt_chart.js`: 表示範囲の制御機能を追加
  - 開始日・終了日の選択UI
  - 選択した期間のみ表示
  - 枠外の作付の処理（表示範囲内のみ表示、移動不可）
- [ ] `crop_palette_drag.js`: ドロップ時の範囲チェック
- [ ] ドラッグアンドドロップの制限ロジック

#### 4.2 API変更
- [ ] `Api::V1::Plans::CultivationPlansController#data`: 表示範囲パラメータを受け取る
- [ ] 表示範囲内の作付のみ返す（または全データを返してフロントでフィルタ）

#### 4.3 テスト
- [ ] JavaScriptのテスト
- [ ] APIのテスト

## 🔍 詳細設計

### データモデル詳細

#### CultivationPlanモデル
```ruby
# バリデーション変更
validates :plan_year, presence: false  # 必須ではなくなる
validates :planning_start_date, presence: true, if: :plan_type_private?
validates :planning_end_date, presence: true, if: :plan_type_private?

# 一意制約変更
validates :farm_id, uniqueness: { 
  scope: [:user_id],  # plan_yearを除外
  message: I18n.t('activerecord.errors.models.cultivation_plan.attributes.farm_id.taken'),
  if: :plan_type_private?
}
```

#### マイグレーション
```ruby
class ChangePrivatePlansToAnnualPlanning < ActiveRecord::Migration[8.0]
  def up
    # 1. plan_yearをnullableに変更
    change_column_null :cultivation_plans, :plan_year, true
    
    # 2. 既存の一意制約を削除
    remove_index :cultivation_plans, 
                  name: 'index_cultivation_plans_on_farm_user_year_unique',
                  if_exists: true
    
    # 3. 新しい一意制約を追加（plan_yearを除外）
    add_index :cultivation_plans, [:farm_id, :user_id], 
              unique: true, 
              name: 'index_cultivation_plans_on_farm_user_unique',
              where: "plan_type = 'private'"
  end
  
  def down
    # ロールバック処理
    remove_index :cultivation_plans, 
                  name: 'index_cultivation_plans_on_farm_user_unique',
                  if_exists: true
    
    add_index :cultivation_plans, [:farm_id, :user_id, :plan_year], 
              unique: true, 
              name: 'index_cultivation_plans_on_farm_user_year_unique',
              where: "plan_type = 'private'"
    
    change_column_null :cultivation_plans, :plan_year, false
  end
end
```

### UI/UX詳細

#### 一覧画面
- 農場別にグループ化
- 各農場の計画をカード表示
- 計画期間を表示（例: "2025/1/1 〜 2026/12/31"）

#### 新規作成画面
- 農場選択のみ（年度選択を削除）
- 計画名入力（オプショナル、デフォルトは農場名）
- 計画期間の設定（将来的に追加可能）

#### 計画表示画面
- 開始日・終了日の選択UI
  - 日付ピッカーで開始日・終了日を選択
  - デフォルトは`planning_start_date`と`planning_end_date`
  - 選択した期間をガントチャートに反映
- ガントチャート
  - 選択した期間のみ表示
  - 枠外の作付は表示範囲内のみ表示（移動不可）

### ガントチャートの表示範囲制御

#### 表示ロジック
1. **表示範囲の設定**
   - ユーザーが選択した開始日・終了日
   - デフォルトは`planning_start_date`と`planning_end_date`

2. **作付の表示判定**
   - 作付の開始日が表示範囲内 → 表示
   - 作付の終了日が表示範囲内 → 表示
   - 作付が表示範囲と重複している → 表示（重複部分のみ）

3. **移動制限の判定**
   - 作付が表示範囲内に完全に収まっている → 移動可能
   - 作付が表示範囲外にかかっている → 移動不可
   - 移動不可の作付はグレーアウトまたは半透明で表示

#### JavaScript実装
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

## 🧪 テスト戦略

### モデルテスト
- [ ] `plan_year`が`null`でもバリデーションが通る
- [ ] 一意制約が`farm_id × user_id`で機能する
- [ ] 既存データの`plan_year`が保持される

### コントローラーテスト
- [ ] 年度選択なしで計画を作成できる
- [ ] 農場別に一覧が表示される
- [ ] 既存の計画が正しく表示される

### 統合テスト
- [ ] 新規作成フローが正常に動作する
- [ ] 表示範囲の選択がガントチャートに反映される
- [ ] 枠外の作付が正しく表示される

### システムテスト
- [ ] ユーザーが計画を作成・編集できる
- [ ] 表示範囲の選択が正常に動作する
- [ ] ドラッグアンドドロップの制限が正常に動作する

## 📝 注意事項

### 後方互換性
- 既存データの`plan_year`は保持する
- 既存の計画はそのまま表示・編集可能
- マイグレーション時に既存データを壊さない

### データ移行
- 既存の計画は`plan_year`を保持
- 新規作成時は`plan_year`を設定しない
- 将来的に`plan_year`を完全に削除する可能性がある

### パフォーマンス
- 一意制約の変更によりインデックスが変わる
- 農場別の一覧表示は適切にインデックスを使用

## 🚀 実装順序

1. **Phase 1**: データモデル変更（マイグレーション、バリデーション）
2. **Phase 2**: コントローラー・Presenter変更
3. **Phase 3**: ビュー変更（一覧、新規作成、表示）
4. **Phase 4**: ガントチャートの表示範囲制御とドラッグアンドドロップ制限

各フェーズでテストを実施し、問題がなければ次のフェーズに進む。

