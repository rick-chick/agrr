# frozen_string_literal: true

# AGRR最適化エンジンとの統合機能を提供するConcern
#
# このConcernは以下の機能を提供します:
# - 現在の割り当てをAGRR形式に変換
# - 圃場・作物設定を構築
# - 交互作用ルールを構築
# - 最適化結果をデータベースに保存
#
# adjust_with_db_weather 内の失敗は HTTP ではなく { success:, message:, status: } ハッシュを返す（例外は種別ごとに rescue）。
module AgrrOptimization
  extend ActiveSupport::Concern


  # 現在の割り当てをAGRR形式に構築
  # @param cultivation_plan [CultivationPlan] 栽培計画
  # @param exclude_ids [Array<Integer>] 除外するfield_cultivationのIDリスト（デフォルト: []）
  def build_current_allocation(cultivation_plan, exclude_ids: [])
    Adapters::CultivationPlan::AgrrOptimizationPayloadBuilder.new(cultivation_plan, logger: Rails.logger)
      .build_current_allocation(exclude_ids: exclude_ids)
  end

  # 圃場設定を構築
  def build_fields_config(cultivation_plan)
    Adapters::CultivationPlan::AgrrOptimizationPayloadBuilder.new(cultivation_plan, logger: Rails.logger)
      .build_fields_config
  end

  # 作物設定を構築
  # 生育ステージのない作物は最適化に使用できないためスキップする
  def build_crops_config(cultivation_plan)
    Adapters::CultivationPlan::AgrrOptimizationPayloadBuilder.new(cultivation_plan, logger: Rails.logger)
      .build_crops_config
  end

  # 交互作用ルールを構築
  def build_interaction_rules(cultivation_plan)
    Adapters::CultivationPlan::AgrrOptimizationPayloadBuilder.new(cultivation_plan, logger: Rails.logger)
      .build_interaction_rules
  end

  # 調整結果をデータベースに保存（永続化の詳細は SaveAdjustedAgrrResult ゲートウェイへ）
  def save_adjusted_result(cultivation_plan, result)
    CompositionRoot.save_adjusted_agrr_result_gateway.save_adjust_result!(
      plan_id: cultivation_plan.id,
      result: result
    )
  end

  # Action Cable経由で最適化完了を通知（チャンネル選択・ブロードキャストはアダプター）
  def broadcast_optimization_complete(cultivation_plan, status: "completed")
    CompositionRoot.cultivation_plan_rest_optimization_events_gateway.broadcast_optimization_complete(
      plan: cultivation_plan,
      status: status
    )
  end


  # DBに保存された天気データを使って調整を実行
  #
  # このメソッドは天気予測を再実行せず、DBに保存された予測データを再利用する
  # これにより、adjust処理が高速化され、不要な予測処理を避けることができる
  #
  # @param cultivation_plan [CultivationPlan] 栽培計画
  # @param moves [Array<Hash>] 移動指示の配列
  # @return [Hash] 調整結果 { success: true/false, ... }
  def adjust_with_db_weather(cultivation_plan, moves)
    CompositionRoot.adjust_with_db_weather_interactor.call(
      plan_id: cultivation_plan.id,
      moves: moves
    )
  end

  # 計画期間を制約として使用しないように、現在の作付の範囲に基づいて動的に計算
  # @param cultivation_plan [CultivationPlan] 栽培計画
  # @param current_allocation [Hash] 現在の割り当てデータ
  # @param moves [Array<Hash>] 移動指示のリスト
  # @return [Array<Date, Date>] [effective_planning_start, effective_planning_end]
  def calculate_effective_planning_period(cultivation_plan, current_allocation, moves)
    cultivation_periods = cultivation_plan.field_cultivations.map do |cultivation|
      {
        start_date: cultivation.start_date,
        completion_date: cultivation.completion_date
      }
    end

    Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
      current_allocation: current_allocation,
      moves: moves,
      cultivation_periods: cultivation_periods,
      planning_start_date: cultivation_plan.planning_start_date,
      planning_end_date: cultivation_plan.planning_end_date,
      as_of: Date.current
    )
  end
end
