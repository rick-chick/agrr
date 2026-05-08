# Private Plans 通年計画設計書 追加考慮事項

> **配置メモ（2026-05）**: 旧 `app/services/plan_save_service.rb` は削除済み。計画保存・複製のオーケストレーションは [`lib/adapters/cultivation_plan/sessions/plan_save_session.rb`](../../lib/adapters/cultivation_plan/sessions/plan_save_session.rb) と関連 Mapper に分散。本章の **PlanSaveService** は歴史的クラス名として読む。

## 📋 概要

設計書 `private_plans_annual_planning_design.md` と検証レポート `private_plans_annual_planning_design_verification.md` を確認し、さらに考慮すべき点をまとめました。

## ⚠️ 検証レポートで指摘されていない追加の考慮事項

### 1. **APIレスポンス（CultivationPlanApi）への影響** ⚠️⚠️

**重要度: 中**

```267:267:app/controllers/concerns/cultivation_plan_api.rb
        plan_year: @cultivation_plan.plan_year,
```

**問題点:**
- `CultivationPlanApi#data`メソッドで`plan_year`をレスポンスに含めている
- フロントエンドのJavaScriptが`plan_year`を期待している可能性がある

**必要な対応:**
- APIレスポンスで`plan_year`が`null`の場合の処理を追加
- フロントエンドが`plan_year`に依存している場合は、後方互換性のため`null`を返すか、期間情報を返す
- または、フロントエンドのコードを確認し、`plan_year`の使用箇所を修正

### 2. **PlanSaveServiceの`find_existing_private_plan`メソッド** ⚠️⚠️⚠️

**重要度: 高**

```ruby
# 旧 plan_save_service に相当する検索（現行は PlanSaveSession / Farm マッパー経由で同等を実施）
def find_existing_private_plan(farm)
    current_year = Date.current.year
    @user.cultivation_plans.where(plan_type: 'private', plan_year: current_year, farm: farm).first
  end
```

**問題点:**
- `plan_year`で既存計画を検索している
- 通年計画（`plan_year`が`null`）の場合、この検索ロジックでは見つからない
- 一意制約が`farm_id × user_id`に変更されるため、`plan_year`での検索は不要になる

**必要な対応:**
- `plan_year`を除外して検索するように変更
- または、`farm_id`と`user_id`のみで検索するように変更
```ruby
def find_existing_private_plan(farm)
  @user.cultivation_plans.where(plan_type: 'private', farm: farm).first
end
```

### 3. **PlanSaveServiceの`calculate_plan_year_from_cultivations`メソッド** ⚠️

**重要度: 中**

```ruby
# 旧 plan_save_service 抜粋（現行は session / mapper に分割）。通年計画では plan_year 検索は不適切。
def calculate_plan_year_from_cultivations(reference_plan)
    field_cultivations = reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil)
    
    # 作付けが存在しない場合は現在の年度を返す
    if field_cultivations.empty?
      Rails.logger.info "⚠️ [PlanSaveService] No field_cultivations found, using current year: #{Date.current.year}"
      return Date.current.year
    end
    
    # 各作付けの期間の中間点を計算
    midpoints = field_cultivations.map do |cultivation|
      start_date = cultivation.start_date
      completion_date = cultivation.completion_date
      
      # 日数を計算して中間点を取得
      days_diff = (completion_date - start_date).to_i
      start_date + days_diff / 2
    end
    
    # 中間点の平均を計算（ユリウス通日を使って平均を計算）
    julian_days = midpoints.map(&:jd)
    avg_julian_day = julian_days.sum / julian_days.size
    avg_date = Date.jd(avg_julian_day.round)
    
    plan_year = avg_date.year
    
    Rails.logger.debug "📊 [PlanSaveService] Field cultivations count: #{field_cultivations.count}"
    Rails.logger.debug "📊 [PlanSaveService] Average midpoint date: #{avg_date}"
    Rails.logger.debug "📊 [PlanSaveService] Calculated plan_year: #{plan_year}"
    
    plan_year
  end
```

**問題点:**
- 作付け期間から年度を算出している
- 通年計画の場合、このメソッドの扱いを検討する必要がある
- `copy_cultivation_plan`メソッドで使用されている（715行目）

**必要な対応:**
- 通年計画の場合、`plan_year`を`null`にする
- または、参照計画が通年計画の場合は、`plan_year`を設定しない
- `planning_start_date`と`planning_end_date`は作付け期間から計算する

### 4. **PlansControllerのセッション管理** ⚠️⚠️

**重要度: 高**

```81:84:app/controllers/plans_controller.rb
        plan_year: session_data[:plan_year],
```

```333:335:app/controllers/plans_controller.rb
    plan_year = session_data[:plan_year].presence || Date.current.year
    plan_name = session_data[:plan_name].presence || farm.name
    planning_dates = CultivationPlan.calculate_planning_dates(plan_year)
```

```361:361:app/controllers/plans_controller.rb
    required_present = session_data[:farm_id].present? && session_data[:plan_year].present?
```

```389:394:app/controllers/plans_controller.rb
    plan_year = session_data[:plan_year]
    Rails.logger.info "🔍 [PlansController#create] Checking for existing plan: farm_id=#{farm.id}, plan_year=#{plan_year}"
    
    existing_plan = current_user.cultivation_plans
      .plan_type_private
      .where(farm: farm, plan_year: plan_year)
      .first
```

**問題点:**
- セッションに`plan_year`を保存している箇所が複数ある
- `validate_session_data`で`plan_year`の存在をチェックしている
- `find_existing_plan`で`plan_year`で検索している

**必要な対応:**
- セッションから`plan_year`を削除
- `validate_session_data`で`plan_year`のチェックを削除
- `find_existing_plan`で`plan_year`を除外して検索
- `build_creator_params`で`plan_year`を使わずに`planning_start_date`と`planning_end_date`を設定

### 5. **PlansControllerの`available_years_range`メソッド** ⚠️

**重要度: 低**

```301:305:app/controllers/plans_controller.rb
  # 年度範囲を計算するヘルパーメソッド
  def available_years_range
    current_year = Date.current.year
    ((current_year - AVAILABLE_YEARS_RANGE)..(current_year + AVAILABLE_YEARS_RANGE)).to_a
  end
```

**問題点:**
- 年度範囲を計算しているが、通年計画では不要になる可能性がある
- ただし、既存データの表示には必要かもしれない

**必要な対応:**
- 既存データの表示に必要かどうかを確認
- 不要であれば削除、必要であれば残す

### 6. **PlansControllerの`AVAILABLE_YEARS_RANGE`定数** ⚠️

**重要度: 低**

```17:18:app/controllers/plans_controller.rb
  # 定数
  AVAILABLE_YEARS_RANGE = 1 # 現在年から前後何年まで表示するか
```

**問題点:**
- 通年計画では年度の概念がなくなるため、この定数は不要になる可能性がある

**必要な対応:**
- 既存データの表示に必要かどうかを確認
- 不要であれば削除、必要であれば残す

### 7. **Plans::IndexPresenterの`plans_by_year`メソッド** ⚠️⚠️

**重要度: 高**

```17:19:app/presenters/plans/index_presenter.rb
    def plans_by_year
      @plans_by_year ||= plans.group_by(&:plan_year)
    end
```

**問題点:**
- 年度別にグループ化している
- 通年計画（`plan_year`が`null`）の場合、`nil`キーでグループ化される
- 設計書では「農場別にグループ化」と記載されている

**必要な対応:**
- 農場別にグループ化するように変更
- `plan_year`が`null`の計画も正しく表示されるようにする

### 8. **Plans::IndexPresenterの`plans`メソッド** ⚠️

**重要度: 中**

```31:38:app/presenters/plans/index_presenter.rb
    def plans
      @plans ||= CultivationPlan
                  .plan_type_private
                  .by_user(@current_user)
                  .select(:id, :status, :plan_year, :plan_name, :total_area, :farm_id, :created_at, :updated_at)
                  .preload(:farm)
                  .recent
    end
```

**問題点:**
- `plan_year`を`select`に含めているが、通年計画では`null`になる可能性がある
- 後方互換性のため残す必要があるかもしれない

**必要な対応:**
- `plan_year`は`select`に含めたまま（後方互換性のため）
- ただし、`plan_year`が`null`でも問題なく動作することを確認

### 9. **Plans::NewPresenterの`available_years`メソッド** ⚠️

**重要度: 中**

```13:15:app/presenters/plans/new_presenter.rb
    def available_years
      @available_years ||= ((current_year - 1)..(current_year + 1)).to_a
    end
```

**問題点:**
- 年度選択UIで使用されているが、設計書では「年度選択UIを削除」と記載されている
- 通年計画では不要になる

**必要な対応:**
- 年度選択UIを削除するため、このメソッドは使用されなくなる
- ただし、既存データの表示には必要かもしれない（確認が必要）

### 10. **作物選択（旧 SelectCropPresenter / `plan_year`）** ⚠️⚠️

**重要度: 高**

```5:12:app/presenters/plans/select_crop_presenter.rb
    def initialize(current_user:, plan_year:, farm_id:)
      @current_user = current_user
      @farm_id = Integer(farm_id)
      @plan_year = Integer(plan_year)
    end

    def plan_year
      @plan_year
    end
```

**問題点:**
- `plan_year`を必須パラメータとして受け取っている
- 設計書では「`plan_year`パラメータを削除」と記載されている

**必要な対応:**
- `plan_year`パラメータを削除
- または、オプショナルにする（既存データの互換性のため）

### 11. **ビューファイルでの`plan_year`の使用** ⚠️⚠️

**重要度: 高**

#### 11.1 `plans/index.html.erb`
```43:44:app/views/plans/index.html.erb
        <% @vm.available_years.reverse.each_with_index do |year, index| %>
          <% year_plans = @vm.plans_by_year[year] %>
```

**問題点:**
- 年度別にグループ化して表示している
- 設計書では「農場別にグループ化」と記載されている

**必要な対応:**
- 農場別にグループ化するように変更
- `plan_year`が`null`の計画も正しく表示されるようにする

#### 11.2 `plans/new.html.erb`
```27:33:app/views/plans/new.html.erb
          <select name="plan_year" required class="plans-form-select">
            <% @vm.available_years.each do |year| %>
              <option value="<%= year %>" <%= 'selected' if year == @vm.current_year %>>
                <%= year %>年度（<%= year - 1 %>年1月〜<%= year + 1 %>年12月）
              </option>
            <% end %>
          </select>
```

**問題点:**
- 年度選択UIがある
- 設計書では「年度選択UIを削除」と記載されている

**必要な対応:**
- 年度選択UIを削除
- 農場選択のみ表示

### 12. **ローカライズファイルでの`plan_year`の使用** ⚠️

**重要度: 低**

検証レポートで指摘されているが、追加で確認すべき点：

- 年度関連のメッセージが複数の言語ファイルに存在する可能性がある
- 通年計画の場合、年度ではなく期間を表示すべき

**必要な対応:**
- 全てのローカライズファイル（`plans.ja.yml`, `plans.us.yml`, `plans.in.yml`など）を確認
- 年度関連のメッセージを期間ベースに変更するか、条件分岐を追加

### 13. **一意制約変更時のマイグレーション戦略** ⚠️⚠️⚠️

**重要度: 高**

**問題点:**
- 既存データで同じ農場・ユーザーに複数の年度の計画が存在する場合、一意制約違反が発生する
- マイグレーション前に重複チェックが必要

**必要な対応:**
- マイグレーション前に重複チェックを実施
- 重複がある場合は、以下のいずれかの対応を検討：
  1. エラーを出してマイグレーションを中止
  2. 重複している計画のうち、最新のもの以外を削除またはマージ
  3. 既存データの`plan_year`を保持し、新規作成時のみ`plan_year`を`null`にする（設計書の方針）

### 14. **既存データの`plan_year`保持と新規データの`plan_year`が`null`の混在** ⚠️⚠️

**重要度: 中**

**問題点:**
- 既存データは`plan_year`が設定されている
- 新規データは`plan_year`が`null`
- この混在により、以下の問題が発生する可能性がある：
  - 一覧画面での表示が不統一
  - 検索・フィルタリングロジックが複雑になる

**必要な対応:**
- 一覧画面で既存データと新規データを統一して表示する方法を検討
- 検索・フィルタリングロジックで`plan_year`が`null`の場合の処理を追加

### 15. **テストコードでの`plan_year`の使用** ⚠️⚠️

**重要度: 高**

検証レポートで指摘されているが、追加で確認すべき点：

- コントローラーのテストで`plan_year`を使用している箇所
- Presenterのテストで`plan_year`を使用している箇所
- システムテストで`plan_year`を使用している箇所

**必要な対応:**
- 全てのテストファイルを確認し、`plan_year`を使用している箇所を修正
- 通年計画のテストを追加

## 📝 設計書に追加すべき項目（追加）

### Phase 1: データモデル変更に追加

- [ ] `PlanSaveService#find_existing_private_plan`の変更（`plan_year`を除外）
- [ ] `PlanSaveService#calculate_plan_year_from_cultivations`の扱い（通年計画の場合）

### Phase 2: コントローラー・Presenter変更に追加

- [ ] `PlansController`のセッション管理の変更（`plan_year`を削除）
- [ ] `PlansController#validate_session_data`の変更（`plan_year`のチェックを削除）
- [ ] `PlansController#find_existing_plan`の変更（`plan_year`を除外）
- [ ] `PlansController#build_creator_params`の変更（`plan_year`を使わずに`planning_start_date`と`planning_end_date`を設定）
- [ ] `Plans::IndexPresenter#plans_by_year`の変更（農場別にグループ化）
- [x] `PrivatePlanSelectCropContextInteractor` に置換済み（`plan_year` はウィザード外）

### Phase 3: ビュー変更に追加

- [ ] `plans/index.html.erb`の変更（年度別から農場別に変更）
- [ ] `plans/new.html.erb`の変更（年度選択UIを削除）

### Phase 5: その他の影響を受ける箇所に追加

#### 5.6 APIレスポンスの変更
- [ ] `CultivationPlanApi#data`で`plan_year`が`null`の場合の処理を追加
- [ ] フロントエンドが`plan_year`に依存している場合は、後方互換性のため`null`を返すか、期間情報を返す

#### 5.7 セッション管理の変更
- [ ] セッションから`plan_year`を削除
- [ ] `validate_session_data`で`plan_year`のチェックを削除
- [ ] `find_existing_plan`で`plan_year`を除外して検索

#### 5.8 マイグレーション戦略の詳細化
- [ ] マイグレーション前に重複チェックを実施
- [ ] 重複がある場合の対応方法を決定
- [ ] 既存データの`plan_year`保持と新規データの`plan_year`が`null`の混在への対応

#### 5.9 ローカライズファイルの確認
- [ ] 全てのローカライズファイル（`plans.ja.yml`, `plans.us.yml`, `plans.in.yml`など）を確認
- [ ] 年度関連のメッセージを期間ベースに変更するか、条件分岐を追加

## 🚨 特に注意すべき点（追加）

### 1. **セッション管理の変更が広範囲に及ぶ**

`PlansController`で`plan_year`をセッションに保存している箇所が複数あり、これらを全て修正する必要がある。

### 2. **APIレスポンスの後方互換性**

フロントエンドのJavaScriptが`plan_year`を期待している可能性があるため、APIレスポンスで`plan_year`が`null`の場合の処理を追加する必要がある。

### 3. **既存データと新規データの混在**

既存データは`plan_year`が設定されており、新規データは`plan_year`が`null`になる。この混在により、一覧画面での表示や検索・フィルタリングロジックが複雑になる可能性がある。

### 4. **マイグレーション時の重複チェック**

既存データで同じ農場・ユーザーに複数の年度の計画が存在する場合、一意制約違反が発生する。マイグレーション前に重複チェックを実施し、適切に対応する必要がある。

## 📊 実装優先度（更新）

### 優先度: 高
1. ✅ Phase 1: データモデル変更
2. ⚠️ `PlanningSchedulesController`の変更（設計書に未記載）
3. ✅ `PlanCopier` interactor 削除・Gateway 集約（2026-05）
4. ⚠️ `PlanSaveService#find_existing_private_plan`の変更（追加）
5. ⚠️ `PlansController`のセッション管理の変更（追加）
6. ⚠️ `Plans::IndexPresenter#plans_by_year`の変更（追加）
7. ⚠️ テストコードの更新（設計書に未記載）

### 優先度: 中
8. ✅ Phase 2: コントローラー・Presenter変更
9. ⚠️ `display_name`メソッドの変更（設計書に未記載）
10. ⚠️ `PlanSaveService#calculate_plan_year_from_cultivations`の扱い（追加）
11. ⚠️ APIレスポンスの変更（追加）
12. ⚠️ データベースインデックスの整理（設計書に未記載）

### 優先度: 低
13. ✅ Phase 3: ビュー変更
14. ✅ Phase 4: ガントチャートの表示範囲制御
15. ⚠️ ローカライズファイルの更新（設計書に未記載）
16. ⚠️ `PlansController#available_years_range`の扱い（追加）

## ✅ まとめ

設計書と検証レポートで主要な変更点はカバーされていますが、以下の点で追加の検討が必要です：

1. **セッション管理の変更** - `PlansController`で`plan_year`をセッションに保存している箇所が複数ある
2. **APIレスポンスの後方互換性** - フロントエンドが`plan_year`を期待している可能性がある
3. **PlanSaveServiceの変更** - `find_existing_private_plan`と`calculate_plan_year_from_cultivations`の扱い
4. **作物選択** — `PrivatePlanSelectCropHtmlPresenter` と `Plans::IndexPresenter` などの整合
5. **マイグレーション戦略** - 既存データと新規データの混在への対応

これらの点を設計書に追加し、実装前に確認することを推奨します。

