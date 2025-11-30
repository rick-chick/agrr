# Private Plans 通年計画設計書 検証レポート

## 📋 検証概要

設計書 `private_plans_annual_planning_design.md` を実装コードと照合し、漏れや追加で考慮すべき点を確認しました。

## ✅ 設計書でカバーされている点

### Phase 1: データモデル変更
- ✅ `plan_year`をnullableに変更するマイグレーション設計
- ✅ 一意制約の変更（`farm_id × user_id`）
- ✅ 既存データの`plan_year`保持（後方互換性）

### Phase 2: コントローラー・Presenter変更
- ✅ `PlansController`の`index`, `new`, `select_crop`, `create`の変更
- ✅ `Plans::IndexPresenter`, `Plans::NewPresenter`, `Plans::SelectCropPresenter`の変更

### Phase 3: ビュー変更
- ✅ `plans/index.html.erb`の年度別→農場別表示
- ✅ `plans/new.html.erb`の年度選択UI削除
- ✅ `plans/show.html.erb`の表示範囲選択UI追加

### Phase 4: ガントチャートの表示範囲制御
- ✅ 表示範囲選択機能の追加
- ✅ 枠外の作付の処理

## ⚠️ 設計書に記載されていないが、影響を受ける箇所

### 1. **`PlanningSchedulesController`への影響** ⚠️⚠️⚠️

**重要度: 高**

`PlanningSchedulesController`は`plan_year`に依存している：

```179:192:app/controllers/planning_schedules_controller.rb
    # 該当年度の計画のみを取得
    plans = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .where(farm: @farm)
      .where(plan_year: plan_years)
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
    
    cultivations = []
    plans.each do |plan|
      plan.field_cultivations.each do |field_cultivation|
        # ほ場名が一致し、期間が重なるものを取得
        # さらに、栽培データの開始年度がplan_yearと一致する場合のみ取得（重複を防ぐため）
        if field_cultivation.cultivation_plan_field.name == field_name &&
           field_cultivation.start_date &&
           field_cultivation.completion_date &&
           field_cultivation.start_date <= end_date &&
           field_cultivation.completion_date >= start_date &&
           field_cultivation.start_date.year == plan.plan_year
```

**問題点:**
- `plan_year`でフィルタリングしている
- `field_cultivation.start_date.year == plan.plan_year`で重複防止している

**必要な対応:**
- `plan_year`が`null`の場合の対応を追加
- `planning_start_date`と`planning_end_date`でフィルタリングする方法に変更
- または、`plan_year`が`null`の計画は通年計画として扱う

### 2. **`display_name`メソッドの変更** ⚠️

**重要度: 中**

```138:145:app/models/cultivation_plan.rb
  # 計画の表示名
  def display_name
    if plan_type_private?
      name = plan_name.presence || I18n.t('models.cultivation_plan.default_plan_name')
      "#{name} (#{plan_year})"
    else
      I18n.t('models.cultivation_plan.public_plan_name')
    end
  end
```

**問題点:**
- `plan_year`が`null`の場合、`"計画名 (nil)"`のように表示される可能性がある
- `plan_year`がない場合は計画期間を表示する方が適切

**必要な対応:**
```ruby
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

### 3. **`PlanCopier`サービスの変更** ⚠️⚠️

**重要度: 高**

```138:166:app/controllers/plans_controller.rb
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    source_plan = @plan
    
    # 新しい年度を決定（現在の計画年度 + 1）
    new_year = source_plan.plan_year + 1
    
    # 既に同じ年度の計画がある場合はエラー
    if current_user.cultivation_plans.plan_type_private.exists?(plan_year: new_year, plan_name: source_plan.plan_name)
      redirect_to plans_path, alert: I18n.t('plans.errors.plan_already_exists', year: new_year) and return
    end
    
    # PlanCopierサービスで計画をコピー
    session_id = session.id.to_s
    result = PlanCopier.new(
      source_plan: source_plan,
      new_year: new_year,
      user: current_user,
      session_id: session_id
    ).call
    
    if result.success?
      redirect_to plan_path(result.new_plan), notice: I18n.t('plans.messages.plan_copied', year: new_year)
    else
      redirect_to plans_path, alert: I18n.t('plans.errors.copy_failed', errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
```

**問題点:**
- `plan_year`が`null`の場合、`new_year = source_plan.plan_year + 1`がエラーになる
- 通年計画の場合、コピー機能をどうするか設計が必要

**必要な対応:**
- 通年計画のコピー機能を削除するか、期間を延長する機能に変更
- または、通年計画の場合はコピー機能を無効化

### 4. **スコープ `by_plan_year`, `for_user_and_year`** ⚠️

**重要度: 中**

```50:52:app/models/cultivation_plan.rb
  scope :by_plan_year, ->(year) { where(plan_year: year) }
  scope :by_plan_name, ->(name) { where(plan_name: name) }
  scope :for_user_and_year, ->(user, year) { plan_type_private.by_user(user).by_plan_year(year) }
```

**問題点:**
- `by_plan_year`は`null`を考慮していない
- `for_user_and_year`も同様

**必要な対応:**
- これらのスコープを使用している箇所を確認し、必要に応じて修正
- または、スコープを非推奨として残し、新しいスコープを追加

### 5. **`calculate_planning_dates`メソッド** ⚠️

**重要度: 低**

```155:161:app/models/cultivation_plan.rb
  # 計画年度から計画期間を計算（2年間）
  def self.calculate_planning_dates(plan_year)
    {
      start_date: Date.new(plan_year, 1, 1),
      end_date: Date.new(plan_year + 1, 12, 31)
    }
  end
```

**問題点:**
- 設計書では「後方互換性のため残す」と記載されているが、新規作成時は使用しない
- `CultivationPlanCreator`や`PlanCopier`で使用されている

**必要な対応:**
- 既存データの互換性のため残す（設計書通り）
- ただし、新規作成時は直接`planning_start_date`と`planning_end_date`を設定する

### 6. **`set_planning_dates_from_year!`メソッド** ⚠️

**重要度: 低**

```171:176:app/models/cultivation_plan.rb
  # 計画期間を設定
  def set_planning_dates_from_year!
    return unless plan_year.present?
    dates = self.class.calculate_planning_dates(plan_year)
    update!(planning_start_date: dates[:start_date], planning_end_date: dates[:end_date])
  end
```

**問題点:**
- `plan_year`が`null`の場合は何もしない（既に正しい動作）

**必要な対応:**
- 特に変更不要（後方互換性のため残す）

### 7. **`this_year_cultivations`と`next_year_cultivations`スコープ** ⚠️

**重要度: 低**

```129:135:app/models/cultivation_plan.rb
  def this_year_cultivations
    field_cultivations.this_year
  end
  
  def next_year_cultivations
    field_cultivations.next_year
  end
```

**問題点:**
- これらのメソッドは`plan_year`に依存していない（`FieldCultivation`のスコープを使用）
- 通年計画でも問題なく動作する

**必要な対応:**
- 変更不要

### 8. **`PlanSaveService`への影響** ⚠️

**重要度: 中**

`PlanSaveService`でも`plan_year`を使用している可能性があるため、確認が必要。

**必要な対応:**
- `PlanSaveService`のコードを確認し、`plan_year`を使用している箇所があれば対応を検討

### 9. **データベースインデックスの整理** ⚠️⚠️

**重要度: 中**

```203:209:db/schema.rb
    t.index ["farm_id", "user_id", "plan_year"], name: "index_cultivation_plans_on_farm_user_year_unique", unique: true, where: "plan_type = 'private'"
    t.index ["farm_id"], name: "index_cultivation_plans_on_farm_id"
    t.index ["plan_type"], name: "index_cultivation_plans_on_plan_type"
    t.index ["session_id"], name: "index_cultivation_plans_on_session_id"
    t.index ["status"], name: "index_cultivation_plans_on_status"
    t.index ["user_id", "plan_name", "plan_year"], name: "index_cultivation_plans_on_user_plan_name_year", where: "plan_type = 'private'"
    t.index ["user_id", "plan_year"], name: "index_cultivation_plans_on_user_id_and_plan_year", where: "plan_type = 'private'"
```

**問題点:**
- `plan_year`を含むインデックスが複数ある
- 一意制約を変更する際に、他のインデックスも整理が必要

**必要な対応:**
- 不要なインデックスを削除するか、条件を更新
- `index_cultivation_plans_on_user_plan_name_year`と`index_cultivation_plans_on_user_id_and_plan_year`の扱いを検討

### 10. **テストコードへの影響** ⚠️⚠️

**重要度: 高**

```40:80:test/models/cultivation_plan_test.rb
  test 'should validate uniqueness of farm_id scoped to user_id and plan_year for private plans' do
    # 最初の計画を作成
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 同じ農場、ユーザ、年で2つ目の計画を作成しようとする
    duplicate_plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    assert_not duplicate_plan.valid?
    assert_includes duplicate_plan.errors[:farm_id], 'この農場の計画は既に存在します'
  end

  test 'should allow same farm_id with different user for private plans' do
    other_user = create(:user)
    other_farm = create(:farm, user: other_user)
    
    # 最初の計画を作成
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 異なるユーザの農場で計画を作成
    other_plan = build(:cultivation_plan, farm: other_farm, user: other_user, plan_year: @plan_year)
    assert other_plan.valid?
  end

  test 'should allow same farm_id and user with different plan_year for private plans' do
    # 最初の計画を作成
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 異なる年で計画を作成
    different_year_plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year + 1)
    assert different_year_plan.valid?
  end

  test 'should allow same farm_id and user with different plan_year for private plans (previous year)' do
    # 最初の計画を作成
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 前の年で計画を作成
    previous_year_plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year - 1)
    assert previous_year_plan.valid?
  end
```

**問題点:**
- 一意制約のテストが年度ベースになっている
- 通年計画のテストが必要

**必要な対応:**
- 既存のテストを更新（通年計画では同じ農場・ユーザで複数の計画を作成できない）
- 通年計画のテストを追加
- `plan_year`が`null`でもバリデーションが通ることを確認するテストを追加

### 11. **Factory定義への影響** ⚠️

**重要度: 中**

テスト用のFactoryで`plan_year`を必須にしている可能性があるため、確認が必要。

**必要な対応:**
- Factory定義を確認し、`plan_year`をオプショナルにする

### 12. **ローカライズファイルへの影響** ⚠️

**重要度: 低**

```43:43:config/locales/views/plans.ja.yml
      plan_copied: "%{year}年の計画をコピーしました。"
```

**問題点:**
- 通年計画の場合、年度ではなく期間を表示すべき

**必要な対応:**
- メッセージを期間ベースに変更するか、条件分岐を追加

## 📝 設計書に追加すべき項目

### 1. **Phase 1: データモデル変更に追加**

- [ ] `display_name`メソッドの変更（`plan_year`が`null`の場合の対応）
- [ ] スコープ`by_plan_year`, `for_user_and_year`の扱い（非推奨化または削除）
- [ ] データベースインデックスの整理（`plan_year`を含むインデックスの扱い）

### 2. **Phase 2: コントローラー・Presenter変更に追加**

- [ ] `PlansController#copy`の変更（通年計画の場合の対応）
- [ ] `PlanningSchedulesController`の変更（`plan_year`依存の除去）

### 3. **Phase 5: その他の影響を受ける箇所**（新規追加）

#### 5.1 `PlanningSchedulesController`の変更
- [ ] `plan_year`によるフィルタリングを`planning_start_date`/`planning_end_date`ベースに変更
- [ ] `field_cultivation.start_date.year == plan.plan_year`の重複防止ロジックを変更
- [ ] 通年計画（`plan_year`が`null`）の対応

#### 5.2 `PlanCopier`サービスの変更
- [ ] 通年計画の場合のコピー機能の扱いを決定
- [ ] `copy`メソッドで`plan_year`が`null`の場合のエラーハンドリング

#### 5.3 `PlanSaveService`の確認
- [ ] `plan_year`を使用している箇所を確認
- [ ] 必要に応じて修正

#### 5.4 テストコードの更新
- [ ] モデルのバリデーションテストの更新
- [ ] 一意制約のテストの更新
- [ ] 通年計画のテストを追加
- [ ] Factory定義の更新

#### 5.5 ローカライズファイルの更新
- [ ] 計画コピー時のメッセージを期間ベースに変更

## 🚨 特に注意すべき点

### 1. **一意制約の変更による既存データへの影響**

マイグレーション時、以下の問題が発生する可能性がある：

- **問題**: 同じ農場・ユーザーで複数の年度の計画が既に存在する場合、一意制約違反が発生する
- **対応**: マイグレーション前に重複チェックを実施し、重複がある場合は事前にエラーを出す
- **または**: 既存データの`plan_year`を保持し、新規作成時のみ`plan_year`を`null`にする（設計書の方針）

### 2. **`PlanningSchedulesController`への影響が大きい**

`PlanningSchedulesController`は`plan_year`に強く依存しているため、設計の再検討が必要：

- 通年計画をどのように扱うか
- 年度ベースの表示機能を維持するか、期間ベースに変更するか

### 3. **計画コピー機能の扱い**

通年計画の場合、コピー機能をどうするか：

- **オプション1**: コピー機能を無効化（通年計画では不要）
- **オプション2**: 計画期間を延長する機能に変更
- **オプション3**: 計画を複製する機能に変更（期間は同じ）

## 📊 実装優先度

### 優先度: 高
1. ✅ Phase 1: データモデル変更
2. ⚠️ `PlanningSchedulesController`の変更（設計書に未記載）
3. ⚠️ `PlanCopier`の変更（設計書に未記載）
4. ⚠️ テストコードの更新（設計書に未記載）

### 優先度: 中
5. ✅ Phase 2: コントローラー・Presenter変更
6. ⚠️ `display_name`メソッドの変更（設計書に未記載）
7. ⚠️ データベースインデックスの整理（設計書に未記載）

### 優先度: 低
8. ✅ Phase 3: ビュー変更
9. ✅ Phase 4: ガントチャートの表示範囲制御
10. ⚠️ ローカライズファイルの更新（設計書に未記載）

## ✅ 検証結果のまとめ

設計書は主要な変更点をカバーしていますが、以下の点で追加の検討が必要です：

1. **`PlanningSchedulesController`への影響** - 設計書に記載がないが、影響が大きい
2. **計画コピー機能の扱い** - 通年計画の場合の対応が不明確
3. **テストコードの更新** - 一意制約の変更に伴うテストの更新が必要
4. **データベースインデックスの整理** - 一意制約変更に伴う整理が必要

これらの点を設計書に追加し、実装前に確認することを推奨します。

