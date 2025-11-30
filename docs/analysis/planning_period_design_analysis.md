# 計画期間設計に関する分析と改善方針

## 概要

本ドキュメントでは、計画期間（`planning_start_date`と`planning_end_date`）の設計について分析し、**表示範囲のみを使用する設計**への移行方針を提案する。

## 設計方針

**計画期間という独立した概念を廃止し、表示範囲（`displayStartDate`, `displayEndDate`）と作付計画から導出される計算値のみを使用する。**

## 問題提起

### 表面的な問題: 柔軟性の欠如

現在のシステムでは、計画期間は計画作成時に固定値で自動設定されており、ユーザーが自由に設定・変更できない。

- **プライベート計画**: 現在年の1月1日から次の年の12月31日まで（約2年間）
- **公開計画**: 今日から今年の年末まで

この固定化により、短期計画や長期計画、不規則な期間への対応ができない。

### 根本的な問題: 概念の必要性

さらに根本的に、「計画期間」という概念自体が本当に必要なのかという疑問が生じる。実際のシステム動作を見ると、計画期間は作付計画（`field_cultivations`）の期間から計算できる導出値に過ぎない可能性がある。

また、フロントエンドでは既に表示範囲（`displayStartDate`, `displayEndDate`）が実装されており、ユーザーが表示範囲を自由に設定できるようになっている。この表示範囲で十分な機能を提供できるため、計画期間という独立した概念は不要である。

## 現状の問題点

### 1. 計画期間の固定化

#### 現在の実装

```ruby
# プライベート計画
planning_start_date = Date.current.beginning_of_year
planning_end_date = Date.new(Date.current.year + 1, 12, 31)

# 公開計画
planning_start_date: Date.current
planning_end_date: Date.current.end_of_year
```

#### 問題点

1. **ユーザーが期間を変更できない**
   - 計画作成時に期間を選択するUIがない
   - 計画作成後に期間を変更する機能がない
   - 通年計画と謳いながら、実質的には固定期間

2. **柔軟性の欠如**
   - 短期計画（例: 半年）への対応不可
   - 長期計画（例: 5年間）への対応不可
   - 不規則な期間（例: 2025年3月1日〜2027年6月30日）への対応不可

### 2. 表示範囲との関係の不明確さ

- 表示範囲は計画期間内に制限される
- 計画期間が固定されているのに、表示範囲だけ変更できるのは不自然
- ユーザーが「計画期間自体を変更したい」という要望に対応できない

### 3. 重要な発見: 計画期間は作付計画から計算されている

実際のコードを見ると、計画期間は作付計画の期間から計算されている：

```ruby
# app/services/plan_save_service.rb:1080-1098
start_dates = field_cultivations.pluck(:start_date).compact
end_dates = field_cultivations.pluck(:completion_date).compact

min_start_date = start_dates.min
max_end_date = end_dates.max

# 計画期間は作付け期間の前後1年を追加
planning_start_date = min_start_date.beginning_of_year
planning_end_date = max_end_date.end_of_year
```

**これは重要な発見である。計画期間は作付計画の期間から導出できる計算値に過ぎない。**

## 批判的検証: 計画期間は本当に必要か？

### 1. 計画期間の使用箇所の検証

#### 1.1 最適化アルゴリズム（要確認）

**現在の実装:**
```ruby
allocation_result = @allocation_gateway.allocate(
  planning_start: @cultivation_plan.planning_start_date,
  planning_end: @cultivation_plan.planning_end_date,
  ...
)
```

**検証:**
- ❓ 最適化アルゴリズムが計画期間を「最適化の対象期間」として使用しているか？
- ✅ 実際の最適化結果は作付計画の期間で決まる
- ✅ 計画期間がなくても、作付計画の期間から計算できる

**結論:**
- 最適化アルゴリズムには作付計画の期間から計算した期間を渡す
- 作付計画がない場合はデフォルト期間を使用する
- 計画期間カラムは不要で、計算メソッドで対応可能

#### 1.2 天気予測

**現在の実装:**
```ruby
target_end_date = cultivation_plan&.planning_end_date
```

**検証結果:**
- 実際に必要なのは作付計画の最長終了日
- `field_cultivations.maximum(:completion_date)`で取得可能

**結論: 計画期間は不要。作付計画の最長終了日から計算可能。**

#### 1.3 ガントチャート表示

**現在の実装:**
```javascript
planStartDate: window.ganttState.planStartDate
planEndDate: window.ganttState.planEndDate
```

**検証結果:**
- 実際に表示するのは作付計画
- 表示範囲はユーザーが設定するもの（`displayStartDate`, `displayEndDate`）
- 計画期間は表示範囲の制限として使われているが、作付計画の期間からも導出可能

**結論: 計画期間は不要。表示範囲はユーザーが設定し、作付計画の期間からも導出可能。**

#### 1.4 作業予定生成

**現在の実装:**
```ruby
start_date = field_cultivation.start_date || plan.planning_start_date
```

**検証結果:**
- `field_cultivation.start_date`があれば十分
- `plan.planning_start_date`はフォールバックとしてのみ使用

**結論: 計画期間は不要。作付計画の開始日があれば十分。**

#### 1.5 作業予定表示（フィルタリング）

**現在の実装:**
```ruby
.where('(planning_start_date <= ? AND planning_end_date >= ?)', end_date, start_date)
```

**検証結果:**
- 作付計画の期間でフィルタリングすれば十分

**結論: 計画期間は不要。作付計画の期間でフィルタリング可能。**

### 2. 計画期間が存在することで生じる問題

#### 2.1 データの不整合リスク

- 計画期間と作付計画の期間が食い違う可能性
- 計画期間を変更した場合、作付計画との整合性を保証できない

**例:**
- 計画期間: 2025年1月1日〜2026年12月31日
- 作付計画: 2025年4月1日〜2025年10月31日
- → 計画期間が実態と合わない

#### 2.2 冗長性による保守コスト

- 計画期間と作付計画の期間を両方管理する必要がある
- 変更時に両方を更新する必要がある
- データ整合性のチェックが必要

#### 2.3 ユーザーの混乱

- 「計画期間」と「表示範囲」と「作付計画の期間」が混在
- ユーザーがどの期間を設定・変更すべきか分からない

#### 2.4 柔軟性の欠如

- 計画期間が固定されているため、ユーザーが期間を自由に設定できない
- 作付計画を追加した場合、計画期間との整合性を保証する必要がある

#### 2.5 ビジネスロジックへの影響

- **天気データ取得**: 計画期間に基づいて天気データを取得するが、固定期間だと不要なデータまで取得する可能性
- **最適化アルゴリズム**: 計画期間内で最適化を実行するが、固定期間だと実際の必要期間外も考慮してしまう
- **作業予定生成**: 計画期間内の作業予定を生成するが、固定期間だと不要な期間の作業予定も生成される可能性

#### 2.6 既存データとの整合性問題

- 既存データ（`plan_year`あり）と新規データ（`plan_year`が`null`だが期間は実質的に年度ベースで固定）が混在
- 年度ベースから期間ベースへの移行が中途半端
- ユーザーから見ると「年度が廃止された」という実感がない

## 結論

### 主な結論

**計画期間という独立した概念を廃止し、表示範囲と作付計画から導出される計算値のみを使用する設計を採用する。**

理由:
1. **計画期間は作付計画の期間から計算できる（導出値）**: 独立したカラムとして保持する必要がない
2. **表示範囲が既に実装されている**: フロントエンドで表示範囲（`displayStartDate`, `displayEndDate`）が既に実装されており、これで十分
3. **データ不整合や冗長性の問題を解消**: 計画期間と作付計画の期間を両方管理する必要がなくなる
4. **ユーザーの混乱を軽減**: 表示範囲だけを意識すればよい、シンプルな設計
5. **柔軟性の向上**: 作付計画を追加すると自動的に期間が拡張される

### 実装における注意点

- **最適化アルゴリズム**: 作付計画がない場合はデフォルト期間を使用し、ある場合は作付計画の期間から計算した期間を使用
- **作付計画がない状態**: 最適化前など、作付計画が存在しない状態ではデフォルト期間を返す計算メソッドを使用
- **表示範囲の管理**: 表示範囲はユーザーが設定可能で、データベースに保存するかセッション/ローカルストレージで管理するかを検討

## 推奨設計: 表示範囲のみを使用する設計

計画期間という独立した概念を完全に廃止し、以下の3つの要素で構成する：

1. **表示範囲** (`displayStartDate`, `displayEndDate`): ユーザーが設定可能な表示期間
2. **作付計画の期間**: 実際の作付計画（`field_cultivations`）から自動計算される期間
3. **計算メソッド**: 作付計画がない場合のデフォルト期間を返す計算メソッド

### 設計の原則

- **計画期間カラムは削除**: `planning_start_date`と`planning_end_date`カラムを削除
- **表示範囲は保存**: ユーザーが設定した表示範囲はデータベースに保存（またはセッション/ローカルストレージ）
- **作付計画の期間から自動計算**: 必要な期間は作付計画から自動的に計算

### 実装方針

#### 1. CultivationPlanモデルの変更

```ruby
class CultivationPlan
  # 計画期間をメソッドとして計算（カラムは持たない）
  def calculated_planning_start_date
    if field_cultivations.any?
      field_cultivations.minimum(:start_date)&.beginning_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      Date.current.beginning_of_year
    end
  end
  
  def calculated_planning_end_date
    if field_cultivations.any?
      field_cultivations.maximum(:completion_date)&.end_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      Date.new(Date.current.year + 1, 12, 31)
    end
  end
  
  def calculated_planning_range
    {
      start_date: calculated_planning_start_date,
      end_date: calculated_planning_end_date
    }
  end
  
  # 互換性のためのエイリアス（段階的移行用）
  alias_method :planning_start_date, :calculated_planning_start_date
  alias_method :planning_end_date, :calculated_planning_end_date
end
```

#### 2. 表示範囲の管理

表示範囲は以下の方法で管理する：

**オプションA: データベースに保存（推奨）**
```ruby
class CultivationPlan
  # 表示範囲をカラムとして保存
  # display_start_date, display_end_date
end
```

**オプションB: セッション/ローカルストレージ（現状の実装を維持）**
- フロントエンドで`window.ganttState.displayStartDate`として管理
- データベースには保存しない

#### 3. 最適化アルゴリズムへの対応

最適化アルゴリズムには、作付計画がない場合はデフォルト期間を、ある場合は作付計画の期間を渡す：

```ruby
class CultivationPlanOptimizer
  def call
    # 作付計画がない場合はデフォルト期間を使用
    planning_start = if @cultivation_plan.field_cultivations.any?
                       @cultivation_plan.calculated_planning_start_date
                     else
                       Date.current.beginning_of_year
                     end
                     
    planning_end = if @cultivation_plan.field_cultivations.any?
                     @cultivation_plan.calculated_planning_end_date
                   else
                     Date.new(Date.current.year + 1, 12, 31)
                   end
    
    allocation_result = @allocation_gateway.allocate(
      fields: fields_data,
      crops: crops_data,
      weather_data: weather_info[:data],
      planning_start: planning_start,
      planning_end: planning_end,
      interaction_rules: interaction_rules
    )
  end
end
```

#### 4. ガントチャート表示の変更

ガントチャートでは、表示範囲を使用して表示する：

```javascript
// 表示範囲が設定されていない場合は、作付計画の期間を使用
const displayStartDate = window.ganttState.displayStartDate || calculatedPlanStartDate;
const displayEndDate = window.ganttState.displayEndDate || calculatedPlanEndDate;
```

### メリット

- ✅ **概念が最もシンプル**: 計画期間という独立した概念が不要
- ✅ **データの不整合が発生しない**: 常に作付計画から計算される
- ✅ **冗長性がなくなる**: 計画期間と作付計画の期間を両方管理する必要がない
- ✅ **保守コストが削減される**: 変更時に両方を更新する必要がない
- ✅ **柔軟性が向上する**: 作付計画を追加すると自動的に期間が拡張される
- ✅ **ユーザーの混乱が少ない**: 表示範囲だけを意識すればよい

### デメリット

- ❌ **計算コスト**: 毎回計算する必要がある（ただし、キャッシュ可能）
- ❌ **既存コードの変更が必要**: 計画期間を参照している箇所を修正する必要がある
- ❌ **マイグレーションが必要**: 既存データの移行が必要

### 移行手順

#### フェーズ1: 計算メソッドの追加と互換性の確保

1. **計算メソッドの追加**
   - `CultivationPlan`モデルに計算メソッドを追加
   - 既存の`planning_start_date`と`planning_end_date`カラムへの参照をエイリアスで対応

2. **既存コードの段階的移行**
   - 既存コードを計算メソッドを使用するように変更
   - テストを追加して動作を確認

#### フェーズ2: 最適化アルゴリズムの対応

3. **最適化アルゴリズムでの使用の変更**
   - 最適化アルゴリズムが計算メソッドを使用するように変更
   - 作付計画がない場合のデフォルト期間の扱いを確認

#### フェーズ3: カラムの削除

4. **カラムの削除**
   - 全てのコードがメソッドを使用するようになったら、カラムを削除するマイグレーションを実行
   - データベースマイグレーションを実行

### 既存の実装状況

現在、フロントエンドでは既に表示範囲（`displayStartDate`, `displayEndDate`）が実装されている：

```javascript
// app/assets/javascripts/custom_gantt_chart.js
window.ganttState = {
  displayStartDate: null,
  displayEndDate: null,
  planStartDate: window.ganttState.planStartDate,
  planEndDate: window.ganttState.planEndDate
};
```

この実装を活かしつつ、バックエンドから計画期間カラムを削除する。

## 設計の具体化

### 1. モデル層の実装詳細

#### 1.1 CultivationPlanモデルの計算メソッド

```ruby
class CultivationPlan < ApplicationRecord
  # 計画期間をメソッドとして計算（カラムは持たない）
  def calculated_planning_start_date
    if field_cultivations.any?
      min_date = field_cultivations.minimum(:start_date)
      return nil unless min_date
      min_date.beginning_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      # プライベート計画: 現在年の1月1日
      # 公開計画: 今日
      if plan_type_private?
        Date.current.beginning_of_year
      else
        Date.current
      end
    end
  end
  
  def calculated_planning_end_date
    if field_cultivations.any?
      max_date = field_cultivations.maximum(:completion_date)
      return nil unless max_date
      max_date.end_of_year
    else
      # 作付計画がない場合のデフォルト値（最適化前など）
      # プライベート計画: 次の年の12月31日
      # 公開計画: 今年の12月31日
      if plan_type_private?
        Date.new(Date.current.year + 1, 12, 31)
      else
        Date.current.end_of_year
      end
    end
  end
  
  def calculated_planning_range
    {
      start_date: calculated_planning_start_date,
      end_date: calculated_planning_end_date
    }
  end
  
  # 互換性のためのエイリアス（段階的移行用）
  # 注意: カラムが存在する場合はカラムを優先し、存在しない場合は計算メソッドを使用
  def planning_start_date
    if has_attribute?(:planning_start_date) && read_attribute(:planning_start_date).present?
      read_attribute(:planning_start_date)
    else
      calculated_planning_start_date
    end
  end
  
  def planning_end_date
    if has_attribute?(:planning_end_date) && read_attribute(:planning_end_date).present?
      read_attribute(:planning_end_date)
    else
      calculated_planning_end_date
    end
  end
  
  # バリデーションの変更
  # 注意: カラム削除後はバリデーションも削除する必要がある
  # validates :planning_start_date, presence: true, if: :plan_type_private?  # 削除予定
  # validates :planning_end_date, presence: true, if: :plan_type_private?      # 削除予定
end
```

#### 1.2 表示範囲の管理（オプションA: データベース保存）

```ruby
# マイグレーション
class AddDisplayDatesToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plans, :display_start_date, :date
    add_column :cultivation_plans, :display_end_date, :date
  end
end

# モデル
class CultivationPlan < ApplicationRecord
  # 表示範囲のデフォルト値（作付計画の期間から計算）
  def display_start_date
    super || calculated_planning_start_date
  end
  
  def display_end_date
    super || calculated_planning_end_date
  end
  
  # 表示範囲を更新
  def update_display_range!(start_date:, end_date:)
    update!(
      display_start_date: start_date,
      display_end_date: end_date
    )
  end
end
```

### 2. サービス層の実装詳細

#### 2.1 CultivationPlanOptimizerの変更

```ruby
class CultivationPlanOptimizer
  def call
    # ... 既存のコード ...
    
    # 計画期間の計算
    planning_start, planning_end = calculate_planning_period
    
    allocation_result = @allocation_gateway.allocate(
      fields: fields_data,
      crops: crops_data,
      weather_data: weather_info[:data],
      planning_start: planning_start,
      planning_end: planning_end,
      interaction_rules: interaction_rules
    )
    
    # ... 既存のコード ...
  end
  
  private
  
  def calculate_planning_period
    # 作付計画がある場合は作付計画の期間から計算
    if @cultivation_plan.field_cultivations.any?
      start_date = @cultivation_plan.calculated_planning_start_date
      end_date = @cultivation_plan.calculated_planning_end_date
      [start_date, end_date]
    else
      # 作付計画がない場合はデフォルト期間を使用
      # プライベート計画と公開計画で異なるデフォルト値
      if @cultivation_plan.plan_type_private?
        [
          Date.current.beginning_of_year,
          Date.new(Date.current.year + 1, 12, 31)
        ]
      else
        [
          Date.current,
          Date.current.end_of_year
        ]
      end
    end
  end
end
```

#### 2.2 WeatherPredictionServiceの変更

```ruby
class WeatherPredictionService
  def predict_for_cultivation_plan(cultivation_plan, target_end_date: nil)
    # 計画期間の終了日を計算メソッドから取得
    target_end_date = normalize_target_end_date(
      target_end_date || cultivation_plan.calculated_planning_end_date
    )
    
    # ... 既存のコード ...
  end
  
  def get_existing_prediction(target_end_date: nil, cultivation_plan: nil)
    # 計画期間の終了日を計算メソッドから取得
    target_end_date ||= cultivation_plan&.calculated_planning_end_date
    target_end_date = normalize_target_end_date(target_end_date)
    
    # ... 既存のコード ...
  end
end
```

#### 2.3 TaskScheduleGeneratorServiceの変更

```ruby
class TaskScheduleGeneratorService
  def generate_for_field(plan, field_cultivation, blueprint_cache)
    # ... 既存のコード ...
    
    # フォールバック: field_cultivation.start_dateがない場合
    # 注意: 計算メソッドを使用するが、field_cultivation.start_dateを優先
    start_date = field_cultivation.start_date || plan.calculated_planning_start_date
    
    # ... 既存のコード ...
  end
end
```

#### 2.4 CultivationPlanCreatorの変更

```ruby
class CultivationPlanCreator
  def create_cultivation_plan
    plan_attrs = {
      farm: @farm,
      user: @user,
      total_area: @total_area,
      plan_type: @plan_type
    }
    
    plan_attrs[:session_id] = @session_id if @session_id.present?
    
    if @plan_type == 'private'
      plan_attrs[:plan_year] = @plan_year
      plan_attrs[:plan_name] = @plan_name.presence || @farm.name
      # 注意: カラム削除前は互換性のため設定するが、削除後は不要
      # plan_attrs[:planning_start_date] = @planning_start_date  # 削除予定
      # plan_attrs[:planning_end_date] = @planning_end_date      # 削除予定
    else
      # 公開計画では計画期間カラムを設定しない（計算メソッドで対応）
      # 注意: カラム削除前は互換性のため設定するが、削除後は不要
      # planning_dates = CultivationPlan.calculate_public_planning_dates
      # plan_attrs[:planning_start_date] = planning_dates[:start_date]  # 削除予定
      # plan_attrs[:planning_end_date] = planning_dates[:end_date]      # 削除予定
    end
    
    @cultivation_plan = CultivationPlan.create!(plan_attrs)
  end
end
```

### 3. コントローラー層の実装詳細

#### 3.1 PlanningSchedulesControllerの変更

```ruby
class PlanningSchedulesController < ApplicationController
  def get_cultivations_for_field(field_name, start_date, end_date)
    # 計画期間カラムでのフィルタリングを削除
    # 代わりに作付計画の期間でフィルタリング
    plans = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .where(farm: @farm)
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
    
    # 注意: 計画期間カラムでのフィルタリングを削除
    # .where('(planning_start_date <= ? AND planning_end_date >= ?)', end_date, start_date)  # 削除
    
    cultivations = []
    plans.each do |plan|
      plan.field_cultivations.each do |field_cultivation|
        # 作付計画の期間でフィルタリング
        if field_cultivation.cultivation_plan_field.name == field_name &&
           field_cultivation.start_date &&
           field_cultivation.completion_date &&
           field_cultivation.start_date <= end_date &&
           field_cultivation.completion_date >= start_date
          
          cultivations << {
            crop_name: field_cultivation.cultivation_plan_crop.name,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            area: field_cultivation.area
          }
        end
      end
    end
    
    cultivations.sort_by { |c| c[:start_date] }
  end
end
```

#### 3.2 CultivationPlanApiの変更

```ruby
module CultivationPlanApi
  def data
    @cultivation_plan = find_api_cultivation_plan
    
    # ... 既存のコード ...
    
    render json: {
      success: true,
      data: {
        id: @cultivation_plan.id,
        plan_year: @cultivation_plan.plan_year,
        plan_name: @cultivation_plan.plan_name,
        status: @cultivation_plan.status,
        total_area: @cultivation_plan.total_area,
        # 計算メソッドを使用
        planning_start_date: @cultivation_plan.calculated_planning_start_date,
        planning_end_date: @cultivation_plan.calculated_planning_end_date,
        # 表示範囲も返す（オプション）
        display_start_date: @cultivation_plan.display_start_date,
        display_end_date: @cultivation_plan.display_end_date,
        fields: fields_data,
        crops: crops_data,
        cultivations: cultivations_data
      },
      # ... 既存のコード ...
    }
  end
end
```

### 4. フロントエンド層の実装詳細

#### 4.1 ガントチャートの表示範囲管理

```javascript
// app/assets/javascripts/custom_gantt_chart.js

// 表示範囲の初期化
function initializeDisplayRange() {
  const container = document.getElementById('gantt-chart-container');
  if (!container) return;
  
  // データ属性から計算された計画期間を取得
  const calculatedStartDate = container.dataset.calculatedPlanStartDate;
  const calculatedEndDate = container.dataset.calculatedPlanEndDate;
  
  // 表示範囲が設定されていない場合は、計算された計画期間を使用
  if (!window.ganttState.displayStartDate) {
    window.ganttState.displayStartDate = calculatedStartDate || 
      window.ganttState.planStartDate;
  }
  
  if (!window.ganttState.displayEndDate) {
    window.ganttState.displayEndDate = calculatedEndDate || 
      window.ganttState.planEndDate;
  }
  
  // 表示範囲をデータベースに保存（オプション）
  saveDisplayRangeToServer();
}

// 表示範囲をサーバーに保存
function saveDisplayRangeToServer() {
  const planId = window.ganttState.cultivation_plan_id;
  if (!planId) return;
  
  fetch(`/api/v1/plans/cultivation_plans/${planId}/update_display_range`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify({
      display_start_date: window.ganttState.displayStartDate,
      display_end_date: window.ganttState.displayEndDate
    })
  }).catch(error => {
    console.error('Failed to save display range:', error);
  });
}
```

#### 4.2 ビューの変更

```erb
<%# app/views/shared/_gantt_chart.html.erb %>

<%
  # 計算された計画期間を取得
  calculated_start_date = cultivation_plan.calculated_planning_start_date || Date.current
  calculated_end_date = cultivation_plan.calculated_planning_end_date || Date.current.end_of_year
  
  # 表示範囲を取得（データベースに保存されている場合）
  display_start_date = cultivation_plan.display_start_date || calculated_start_date
  display_end_date = cultivation_plan.display_end_date || calculated_end_date
%>

<div id="gantt-chart-container"
     data-calculated-plan-start-date="<%= calculated_start_date.to_s %>"
     data-calculated-plan-end-date="<%= calculated_end_date.to_s %>"
     data-display-start-date="<%= display_start_date.to_s %>"
     data-display-end-date="<%= display_end_date.to_s %>"
     ...>
</div>
```

## 注意点とリスク管理

### 1. エッジケースと例外処理

#### 1.1 作付計画がない状態

**問題:**
- 最適化前など、作付計画が存在しない状態で計画期間が必要になる

**対策:**
- デフォルト期間を返す計算メソッドを実装
- プライベート計画と公開計画で異なるデフォルト値を設定
- 作付計画が追加されたら自動的に期間が更新される

**実装例:**
```ruby
def calculated_planning_start_date
  if field_cultivations.any?
    field_cultivations.minimum(:start_date)&.beginning_of_year
  else
    # デフォルト値
    plan_type_private? ? Date.current.beginning_of_year : Date.current
  end
end
```

#### 1.2 作付計画の日付がnilの場合

**問題:**
- `field_cultivations`に`start_date`や`completion_date`が`nil`のレコードが存在する可能性

**対策:**
- `compact`を使用して`nil`を除外
- `minimum`/`maximum`の結果が`nil`の場合はデフォルト値を返す

**実装例:**
```ruby
def calculated_planning_start_date
  if field_cultivations.any?
    min_date = field_cultivations.pluck(:start_date).compact.min
    return default_start_date unless min_date
    min_date.beginning_of_year
  else
    default_start_date
  end
end
```

#### 1.3 作付計画が削除された場合

**問題:**
- 全ての作付計画が削除された場合、期間がどうなるか

**対策:**
- 作付計画が0件になったらデフォルト期間を返す
- 表示範囲は保持する（ユーザーが設定した表示範囲は維持）

**実装例:**
```ruby
def calculated_planning_start_date
  return default_start_date unless field_cultivations.any?
  # ... 既存のコード ...
end
```

### 2. パフォーマンス考慮事項

#### 2.1 計算コストの最適化

**問題:**
- `field_cultivations.minimum(:start_date)`や`maximum(:completion_date)`は毎回DBクエリを実行する

**対策:**
- メモ化（memoization）を使用して計算結果をキャッシュ
- `field_cultivations`が変更されたらキャッシュをクリア

**実装例:**
```ruby
class CultivationPlan < ApplicationRecord
  after_save :clear_planning_period_cache, if: :saved_change_to_field_cultivations?
  
  def calculated_planning_start_date
    @calculated_planning_start_date ||= begin
      if field_cultivations.any?
        min_date = field_cultivations.minimum(:start_date)
        min_date&.beginning_of_year || default_start_date
      else
        default_start_date
      end
    end
  end
  
  private
  
  def clear_planning_period_cache
    @calculated_planning_start_date = nil
    @calculated_planning_end_date = nil
  end
end
```

#### 2.2 N+1クエリの回避

**問題:**
- 複数の計画に対して計算メソッドを呼び出すとN+1クエリが発生

**対策:**
- `includes`を使用して`field_cultivations`を事前読み込み
- バッチ処理で計算結果をキャッシュ

**実装例:**
```ruby
# コントローラー
@plans = CultivationPlan.includes(:field_cultivations).all

# ビュー
@plans.each do |plan|
  start_date = plan.calculated_planning_start_date  # N+1クエリなし
end
```

### 3. データ整合性の保証

#### 3.1 移行時のデータ整合性

**問題:**
- 既存データの計画期間カラムと計算メソッドの結果が一致しない可能性

**対策:**
- 移行前にデータ整合性チェックを実行
- 不一致がある場合は警告を出して手動確認を促す

**実装例:**
```ruby
# マイグレーション
class ValidatePlanningPeriodConsistency < ActiveRecord::Migration[8.0]
  def up
    inconsistent_plans = []
    
    CultivationPlan.find_each do |plan|
      calculated_start = plan.calculated_planning_start_date
      calculated_end = plan.calculated_planning_end_date
      
      if plan.planning_start_date != calculated_start ||
         plan.planning_end_date != calculated_end
        inconsistent_plans << {
          id: plan.id,
          stored: { start: plan.planning_start_date, end: plan.planning_end_date },
          calculated: { start: calculated_start, end: calculated_end }
        }
      end
    end
    
    if inconsistent_plans.any?
      Rails.logger.warn "⚠️ Inconsistent planning periods found: #{inconsistent_plans.inspect}"
      # 必要に応じて手動確認を促す
    end
  end
end
```

#### 3.2 バリデーションの変更

**問題:**
- 計画期間カラムのバリデーションが残っているとエラーになる

**対策:**
- カラム削除前にバリデーションを削除
- 計算メソッドの結果が`nil`になる場合はエラーを上げる

**実装例:**
```ruby
class CultivationPlan < ApplicationRecord
  # カラム削除前: バリデーションをコメントアウト
  # validates :planning_start_date, presence: true, if: :plan_type_private?  # 削除予定
  # validates :planning_end_date, presence: true, if: :plan_type_private?   # 削除予定
  
  # カラム削除後: 計算メソッドの結果を検証
  validate :calculated_planning_period_present, if: :plan_type_private?
  
  private
  
  def calculated_planning_period_present
    if calculated_planning_start_date.nil? || calculated_planning_end_date.nil?
      errors.add(:base, '計画期間を計算できません')
    end
  end
end
```

### 4. 移行時のリスクと対策

#### 4.1 段階的移行の重要性

**リスク:**
- 一度に全てを変更すると、予期しないエラーが発生する可能性

**対策:**
- フェーズ1: 計算メソッドの追加と互換性の確保
- フェーズ2: 既存コードの段階的移行
- フェーズ3: カラムの削除
- 各フェーズでテストを実行して動作を確認

#### 4.2 ロールバック計画

**リスク:**
- 移行中に問題が発生した場合のロールバック方法

**対策:**
- カラム削除前は計算メソッドとカラムの両方をサポート
- カラム削除後は計算メソッドのみを使用
- 問題が発生した場合は、カラムを再追加するマイグレーションを用意

**実装例:**
```ruby
# ロールバック用マイグレーション
class RollbackPlanningPeriodRemoval < ActiveRecord::Migration[8.0]
  def up
    # カラムを再追加
    add_column :cultivation_plans, :planning_start_date, :date
    add_column :cultivation_plans, :planning_end_date, :date
    
    # 計算メソッドの結果でカラムを更新
    CultivationPlan.find_each do |plan|
      plan.update_columns(
        planning_start_date: plan.calculated_planning_start_date,
        planning_end_date: plan.calculated_planning_end_date
      )
    end
  end
end
```

### 5. テスト戦略

#### 5.1 単体テスト

**テスト項目:**
- 計算メソッドの動作確認
- 作付計画がある場合とない場合の両方をテスト
- エッジケース（nil、空配列など）のテスト

**実装例:**
```ruby
# test/models/cultivation_plan_test.rb
class CultivationPlanTest < ActiveSupport::TestCase
  test "calculated_planning_start_date with field_cultivations" do
    plan = cultivation_plans(:private_plan)
    field_cultivation = field_cultivations(:one)
    field_cultivation.update!(start_date: Date.new(2025, 4, 1))
    
    assert_equal Date.new(2025, 1, 1), plan.calculated_planning_start_date
  end
  
  test "calculated_planning_start_date without field_cultivations" do
    plan = cultivation_plans(:private_plan)
    plan.field_cultivations.destroy_all
    
    assert_equal Date.current.beginning_of_year, plan.calculated_planning_start_date
  end
  
  test "calculated_planning_start_date with nil dates" do
    plan = cultivation_plans(:private_plan)
    field_cultivation = field_cultivations(:one)
    field_cultivation.update!(start_date: nil)
    
    # nilの場合はデフォルト値を返す
    assert_equal Date.current.beginning_of_year, plan.calculated_planning_start_date
  end
end
```

#### 5.2 統合テスト

**テスト項目:**
- 最適化アルゴリズムでの使用
- 天気予測での使用
- 作業予定生成での使用
- APIでの期間情報の返却

**実装例:**
```ruby
# test/services/cultivation_plan_optimizer_test.rb
class CultivationPlanOptimizerTest < ActiveSupport::TestCase
  test "optimizer uses calculated planning period" do
    plan = cultivation_plans(:private_plan)
    field_cultivation = field_cultivations(:one)
    field_cultivation.update!(
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    optimizer = CultivationPlanOptimizer.new(plan, PlansOptimizationChannel)
    
    # 最適化アルゴリズムが計算メソッドを使用することを確認
    # （モックを使用して検証）
  end
end
```

#### 5.3 システムテスト

**テスト項目:**
- ガントチャートでの表示範囲の動作
- 計画作成時の動作
- 計画期間の表示

**実装例:**
```ruby
# test/system/planning_period_test.rb
class PlanningPeriodTest < ApplicationSystemTestCase
  test "display range is used in gantt chart" do
    visit plan_path(cultivation_plans(:private_plan))
    
    # 表示範囲が正しく設定されていることを確認
    assert_selector '[data-display-start-date]'
    assert_selector '[data-display-end-date]'
  end
end
```

### 6. 既存コードへの影響

#### 6.1 影響を受けるファイル一覧

**モデル:**
- `app/models/cultivation_plan.rb`: 計算メソッドの追加、バリデーションの変更

**サービス:**
- `app/services/cultivation_plan_optimizer.rb`: 計算メソッドの使用
- `app/services/weather_prediction_service.rb`: 計算メソッドの使用
- `app/services/task_schedule_generator_service.rb`: 計算メソッドの使用
- `app/services/cultivation_plan_creator.rb`: 計画期間カラムの設定を削除
- `app/services/plan_save_service.rb`: 計画期間の計算ロジックを削除（計算メソッドに移行）

**コントローラー:**
- `app/controllers/plans_controller.rb`: 計画作成時の期間設定を削除
- `app/controllers/planning_schedules_controller.rb`: フィルタリングロジックの変更
- `app/controllers/concerns/cultivation_plan_api.rb`: APIでの期間情報の返却を変更

**ビュー・フロントエンド:**
- `app/views/shared/_gantt_chart.html.erb`: 計算された計画期間のデータ属性を追加
- `app/assets/javascripts/custom_gantt_chart.js`: 表示範囲の管理を強化

#### 6.2 後方互換性の維持

**方針:**
- カラム削除前は、カラムと計算メソッドの両方をサポート
- カラムが存在する場合はカラムを優先し、存在しない場合は計算メソッドを使用
- 段階的に移行することで、既存コードへの影響を最小化

**実装例:**
```ruby
def planning_start_date
  # カラムが存在し、値がある場合はカラムを優先
  if has_attribute?(:planning_start_date) && read_attribute(:planning_start_date).present?
    read_attribute(:planning_start_date)
  else
    # カラムが存在しない、または値がnilの場合は計算メソッドを使用
    calculated_planning_start_date
  end
end
```

## 実装優先度と手順

### フェーズ1: 検証と準備（最優先）

1. **影響範囲の詳細調査**
   - 計画期間（`planning_start_date`, `planning_end_date`）を使用している全ての箇所を洗い出す
   - 各箇所で計画期間が本当に必要かを検証
   - 表示範囲との関係を確認

2. **最適化アルゴリズムの詳細確認**
   - 最適化アルゴリズムが計画期間をどのように使用しているか
   - 計画期間が最適化結果に与える影響
   - 作付計画の期間から計算した期間で最適化アルゴリズムが正常に動作するか

3. **表示範囲の実装状況確認**
   - フロントエンドでの表示範囲の実装状況を確認
   - 表示範囲をデータベースに保存するか、セッション/ローカルストレージで管理するかを決定

### フェーズ2: 計算メソッドの追加と互換性の確保（高優先度）

4. **計算メソッドの追加**
   - `CultivationPlan`モデルに計算メソッドを追加
   - 既存のカラムへの参照をエイリアスで対応
   - 作付計画がない場合のデフォルト期間の扱いを実装

5. **テストの追加**
   - 計算メソッドのテストを追加
   - 既存のテストが正常に動作することを確認

### フェーズ3: 既存コードの段階的移行（高優先度）

6. **最適化アルゴリズムの変更**
   - 最適化アルゴリズムが計算メソッドを使用するように変更
   - テストを追加して動作を確認

7. **その他の使用箇所の変更**
   - 計画期間を使用している他の箇所を計算メソッドを使用するように変更
   - テストを追加して動作を確認

8. **フロントエンドの調整**
   - 表示範囲の扱いを統一
   - 計画期間カラムに依存しない実装に変更

### フェーズ4: カラムの削除（中優先度）

9. **カラムの削除準備**
   - 全てのコードがメソッドを使用するようになったことを確認
   - 既存データの移行計画を策定

10. **マイグレーションの実行**
    - カラムを削除するマイグレーションを実行
    - データの整合性を確認

## 関連ファイル

### モデル
- `app/models/cultivation_plan.rb`: 計画期間の定義とバリデーション

### サービス
- `app/services/cultivation_plan_optimizer.rb`: 最適化での使用（要確認）
- `app/services/weather_prediction_service.rb`: 天気予測での使用
- `app/services/plan_save_service.rb`: 計画期間の計算ロジック（重要な参考）
- `app/services/cultivation_plan_creator.rb`: 計画作成サービス
- `app/services/task_schedule_generator_service.rb`: 作業予定生成での使用

### コントローラー
- `app/controllers/plans_controller.rb`: 計画作成時の期間設定
- `app/controllers/planning_schedules_controller.rb`: フィルタリングでの使用
- `app/controllers/concerns/cultivation_plan_api.rb`: APIでの期間情報の返却

### ビュー・フロントエンド
- `app/views/plans/new.html.erb`: 計画作成UI
- `app/views/plans/show.html.erb`: 計画詳細画面（期間表示）
- `app/assets/javascripts/custom_gantt_chart.js`: ガントチャートでの期間表示

## まとめ

計画期間の設計には以下の問題がある：

1. **表面的な問題**: 計画期間が固定されており、ユーザーが自由に設定できない
2. **根本的な問題**: 計画期間という概念自体が不要である可能性が高い

**解決策として、計画期間という独立した概念を廃止し、表示範囲と作付計画から導出される計算値のみを使用する設計を採用する。**

この設計により：
- データ不整合のリスクを減らす
- 保守コストを削減する
- 柔軟性を向上させる
- ユーザーの混乱を軽減する

実装においては、段階的な移行を行い、既存のコードとの互換性を保ちながら、計画期間カラムを削除する。

