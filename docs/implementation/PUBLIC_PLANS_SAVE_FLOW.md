# Public Plans Save機能 - データフローとコンポーネント間の移送

## 📋 概要

本ドキュメントでは、Public Plans Save機能のデータフローとコンポーネント間の移送を詳しく説明します。

## 🎯 機能の全体像

Public Plans Save機能は、ユーザーが公開計画を自分のアカウントに保存できる機能です。以下の2つのシナリオをサポートします：

1. **ログイン済みユーザー**: 直接保存処理を実行
2. **未ログインユーザー**: ログイン画面へリダイレクト → ログイン後、自動的に保存処理を実行

---

## 📊 データフローダイアグラム

### シナリオ1: ログイン済みユーザー

```
[Results Page]
    ↓ [フォーム送信]
[PublicPlansController#save_plan]
    ↓ (logged_in? = true)
[save_plan_to_user_account]
    ↓ [PlanSaveService.new.call]
[PlanSaveService#call]
    ├─ [create_or_get_user_farm] → UserFarm作成/取得
    ├─ [create_user_crops_from_plan] → 参照計画からUserCrops新規作成
    ├─ [copy_cultivation_plan] → CultivationPlanコピー
    └─ [copy_plan_relations] → 関連データコピー
    ↓ [成功]
[plans_path へリダイレクト]
```

### シナリオ2: 未ログインユーザー

```
[Results Page]
    ↓ [フォーム送信]
[PublicPlansController#save_plan]
    ↓ (logged_in? = false)
[save_plan_data_to_session]
    ↓ [session[:public_plan_save_data] = {...}]
[AuthController#login へリダイレクト]
    ↓ [Google OAuth認証]
[AuthController#google_oauth2_callback]
    ↓ [セッション作成]
[process_saved_plan_public_plans_path へリダイレクト]
    ↓
[PublicPlansController#process_saved_plan]
    ↓ [PlanSaveService.new.call]
[PlanSaveService#call]
    ├─ [create_or_get_user_farm] → UserFarm作成/取得
    ├─ [create_user_crops_from_plan] → 参照計画からUserCrops新規作成
    ├─ [copy_cultivation_plan] → CultivationPlanコピー
    └─ [copy_plan_relations] → 関連データコピー
    ↓ [成功]
[plans_path へリダイレクト]
```

---

## 🧩 コンポーネント間の移送

### 1. View → Controller

#### ファイル: `app/views/public_plans/results.html.erb`
```erb
<%= form_with url: save_plan_public_plans_path, method: :post, local: true, id: "save-plan-form" do |f| %>
  <%= f.submit t('public_plans.save.button'), class: "btn-primary", id: "save-plan-button" %>
<% end %>
```

**移送データ**:
- HTTP POSTリクエスト
- URL: `/public_plans/save_plan`

---

### 2. Controller → Service

#### ファイル: `app/controllers/public_plans_controller.rb`

##### 2.1 ログイン済みの場合

```ruby
def save_plan
  @cultivation_plan = find_cultivation_plan
  
  if logged_in?
    save_plan_to_user_account
  else
    save_plan_data_to_session
    redirect_to auth_login_path
  end
end

def save_plan_to_user_account
  # セッションデータを構築
  save_data = {
    plan_id: @cultivation_plan.id,
    farm_id: session_data[:farm_id],
    crop_ids: session_data[:crop_ids]
  }
  
  # PlanSaveServiceを呼び出し
  result = PlanSaveService.new(
    user: current_user,
    session_data: save_data
  ).call
  
  if result.success
    redirect_to plans_path, notice: I18n.t('public_plans.save.success')
  else
    redirect_to results_public_plans_path, alert: result.error_message
  end
end
```

**移送データ**:
```ruby
{
  user: #<User id: 2>,
  session_data: {
    plan_id: 312,
    farm_id: 1,
    crop_ids: [1, 2, 3]
  }
}
```

##### 2.2 未ログインの場合

```ruby
def save_plan_data_to_session
  session[:public_plan_save_data] = {
    plan_id: @cultivation_plan.id,
    farm_id: session_data[:farm_id],
    crop_ids: session_data[:crop_ids]
  }
end
```

**移送データ** (セッションに保存):
```ruby
session[:public_plan_save_data] = {
  plan_id: 312,
  farm_id: 1,
  crop_ids: [1, 2, 3]
}
```

---

### 3. Controller → Auth Controller

#### ファイル: `app/controllers/auth_controller.rb`

```ruby
def google_oauth2_callback
  # 認証処理
  user = User.from_omniauth(auth_hash)
  
  # セッション作成
  session = Session.create_for_user(user)
  cookies[:session_id] = {...}
  
  # セッションデータが存在する場合は保存処理へリダイレクト
  redirect_to process_saved_plan_public_plans_path if session[:public_plan_save_data]
end
```

**移送データ**: なし（セッションを使用）

---

### 4. PlanSaveService 内部の処理

#### ファイル: `app/services/plan_save_service.rb`

##### 4.1 初期化

```ruby
def initialize(user:, session_data:)
  @user = user
  @session_data = session_data
  @result = OpenStruct.new(success: false, error_message: nil)
end
```

**入力データ**:
- `user`: ログインユーザー
- `session_data`: 計画情報

##### 4.2 メイン処理

```ruby
def call
  ActiveRecord::Base.transaction do
    # 1. マスタデータの作成・取得
    farm = create_or_get_user_farm
    crops = create_user_crops_from_plan
    interaction_rules = create_interaction_rules(crops)
    
    # 2. 計画のコピー
    new_plan = copy_cultivation_plan(farm, crops)
    
    # 3. マスタデータ間の関連付け
    establish_master_data_relationships(farm, crops, interaction_rules)
    
    # 4. 関連データのコピー
    copy_plan_relations(new_plan)
    
    @result.success = true
  end
  
  @result
rescue => e
  Rails.logger.error "PlanSaveService error: #{e.message}"
  @result.error_message = e.message
  @result
end
```

##### 4.3 農場の作成・取得

```ruby
def create_or_get_user_farm
  farm_id = @session_data[:farm_id] || @session_data['farm_id']
  reference_farm = Farm.find(farm_id)
  
  # 既存の農場があるかチェック
  existing_farm = @user.farms.find_by(
    latitude: reference_farm.latitude,
    longitude: reference_farm.longitude
  )
  
  return existing_farm if existing_farm
  
  # 新しい農場を作成
  @user.farms.create!(
    name: "#{reference_farm.name} (コピー)",
    latitude: reference_farm.latitude,
    longitude: reference_farm.longitude,
    region: reference_farm.region,
    is_reference: false,
    weather_location_id: reference_farm.weather_location_id
  )
end
```

**DB操作**:
- `SELECT` で参照農場を取得
- `SELECT` で既存の農場を検索
- `INSERT` で新しい農場を作成（必要に応じて）

##### 4.4 作物の作成・取得

```ruby
def create_user_crops_from_plan
  crop_ids = @session_data[:crop_ids] || @session_data['crop_ids']
  reference_crops = Crop.includes(crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement])
                        .where(id: crop_ids)
  user_crops = []
  
  reference_crops.each do |reference_crop|
    existing_crop = @user.crops.find_by(name: reference_crop.name)
    
    if existing_crop
      user_crops << existing_crop
    else
      new_crop = @user.crops.create!(
        name: reference_crop.name,
        variety: reference_crop.variety,
        area_per_unit: reference_crop.area_per_unit,
        revenue_per_area: reference_crop.revenue_per_area,
        groups: reference_crop.groups,
        is_reference: false,
        region: reference_crop.region
      )
      
      copy_crop_stages(reference_crop, new_crop)
      user_crops << new_crop
    end
  end
  
  user_crops
end
```

**DB操作**:
- `SELECT` で参照作物を取得（関連データも eager loading）
- `SELECT` で既存の作物を検索
- `INSERT` で新しい作物を作成（必要に応じて）
- `INSERT` で作物ステージを作成（必要に応じて）

##### 4.5 計画のコピー

```ruby
def copy_cultivation_plan(farm, crops)
  plan_id = @session_data[:plan_id] || @session_data['plan_id']
  reference_plan = CultivationPlan.find(plan_id)
  
  @user.cultivation_plans.create!(
    farm: farm,
    plan_type: :private,
    total_area: reference_plan.total_area,
    status: :completed,
    planning_start_date: reference_plan.planning_start_date,
    planning_end_date: reference_plan.planning_end_date,
    plan_year: reference_plan.plan_year || Date.current.year,
    total_profit: reference_plan.total_profit,
    total_revenue: reference_plan.total_revenue,
    total_cost: reference_plan.total_cost,
    optimization_time: reference_plan.optimization_time,
    algorithm_used: reference_plan.algorithm_used,
    is_optimal: reference_plan.is_optimal,
    optimization_summary: reference_plan.optimization_summary,
    predicted_weather_data: reference_plan.predicted_weather_data
  )
end
```

**DB操作**:
- `SELECT` で参照計画を取得
- `INSERT` で新しい計画を作成

##### 4.6 関連データのコピー

```ruby
def copy_plan_relations(new_plan)
  plan_id = @session_data[:plan_id] || @session_data['plan_id']
  reference_plan = CultivationPlan.includes(
    :cultivation_plan_fields,
    :cultivation_plan_crops,
    :field_cultivations,
    cultivation_plan_crops: :crop,
    field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop]
  ).find(plan_id)
  
  # CultivationPlanFieldをコピー（バルクインサート）
  field_data = reference_plan.cultivation_plan_fields.map do |reference_field|
    {
      cultivation_plan_id: new_plan.id,
      name: reference_field.name,
      area: reference_field.area,
      daily_fixed_cost: reference_field.daily_fixed_cost,
      description: reference_field.description,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
  CultivationPlanField.insert_all(field_data) if field_data.any?
  
  # CultivationPlanCropをコピー（バルクインサート）
  crop_plan_data = []
  reference_plan.cultivation_plan_crops.each do |reference_crop_plan|
    crop = @user.crops.find_by(name: reference_crop_plan.crop.name)
    next unless crop
    
    crop_plan_data << {
      cultivation_plan_id: new_plan.id,
      crop_id: crop.id,
      name: reference_crop_plan.name,
      variety: reference_crop_plan.variety,
      area_per_unit: reference_crop_plan.area_per_unit,
      revenue_per_area: reference_crop_plan.revenue_per_area,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
  CultivationPlanCrop.insert_all(crop_plan_data) if crop_plan_data.any?
  
  # FieldCultivationをコピー（バルクインサート）
  field_cultivation_data = []
  reference_plan.field_cultivations.each do |reference_field_cultivation|
    plan_field = field_map[reference_field_cultivation.cultivation_plan_field.name]
    next unless plan_field
    
    plan_crop = crop_map[reference_field_cultivation.cultivation_plan_crop.name]
    next unless plan_crop
    
    field_cultivation_data << {
      cultivation_plan_id: new_plan.id,
      cultivation_plan_field_id: plan_field.id,
      cultivation_plan_crop_id: plan_crop.id,
      area: reference_field_cultivation.area,
      start_date: reference_field_cultivation.start_date,
      completion_date: reference_field_cultivation.completion_date,
      estimated_cost: reference_field_cultivation.estimated_cost,
      status: reference_field_cultivation.status,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
  FieldCultivation.insert_all(field_cultivation_data) if field_cultivation_data.any?
end
```

**DB操作**:
- `SELECT` で参照計画の関連データを取得（eager loading）
- `INSERT ALL` で CultivationPlanField をバルクインサート
- `INSERT ALL` で CultivationPlanCrop をバルクインサート
- `INSERT ALL` で FieldCultivation をバルクインサート

---

## 🔄 データ変換とマッピング

### 1. 農場データの変換

| 参照農場 | ユーザー農場 |
|---------|------------|
| `name` | `name + " (コピー)"` |
| `is_reference: true` | `is_reference: false` |
| `user_id: nil` | `user_id: current_user.id` |

### 2. 作物データの変換

| 参照作物 | ユーザー作物 |
|---------|------------|
| `is_reference: true` | `is_reference: false` |
| `user_id: nil` | `user_id: current_user.id` |

### 3. 作物ステージ要件のコピー

```ruby
def copy_crop_stages(reference_crop, new_crop)
  reference_crop.crop_stages.each do |reference_stage|
    new_stage = CropStage.create!(
      crop_id: new_crop.id,
      name: reference_stage.name,
      order: reference_stage.order
    )
    
    # 温度要件をコピー
    if reference_stage.temperature_requirement
      TemperatureRequirement.create!(
        crop_stage_id: new_stage.id,
        base_temperature: reference_stage.temperature_requirement.base_temperature,
        optimal_min: reference_stage.temperature_requirement.optimal_min,
        optimal_max: reference_stage.temperature_requirement.optimal_max,
        # ... 他のフィールド
      )
    end
    
    # 日照要件をコピー
    # 熱量要件をコピー
  end
end
```

### 4. 計画データの変換

| 参照計画 | ユーザー計画 |
|---------|------------|
| `plan_type: 'public'` | `plan_type: 'private'` |
| `user_id: nil` | `user_id: current_user.id` |
| `status: 'completed'` | `status: 'completed'` |

---

## 🗄️ データベース操作の流れ

### トランザクション管理

```ruby
def call
  ActiveRecord::Base.transaction do
    # すべてのDB操作はトランザクション内で実行
    # エラーが発生した場合は全てロールバック
  end
  
  @result
rescue => e
  # エラーハンドリング
  @result.error_message = e.message
  @result
end
```

### パフォーマンス最適化

1. **Eager Loading**: `includes`で関連データを事前読み込み
2. **Bulk Insert**: `insert_all`でバルクインサート
3. **Memory Maps**: `index_by`でメモリマップを作成して`find_by`を削減

---

## 📝 まとめ

Public Plans Save機能は、以下の流れで動作します：

1. **ユーザー操作**: Results画面で「マイプランに保存」ボタンをクリック
2. **認証チェック**: ログイン状態を確認
3. **セッション管理**: 未ログインの場合はセッションに保存データを格納
4. **認証**: 未ログインの場合はGoogle OAuthでログイン
5. **データコピー**: PlanSaveServiceで計画データをコピー
6. **完了**: plans画面へリダイレクト

各コンポーネント間のデータ移送は、HTTPリクエスト、セッション、サービスメソッドを通じて行われます。
