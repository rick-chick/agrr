# frozen_string_literal: true

module Plans
  class IndexPresenter
    def initialize(current_user:)
      @current_user = current_user
    end

    def plans_by_farm
      @plans_by_farm ||= plans.group_by(&:farm_id)
    end

    # @deprecated 年度によるグループ化は非推奨です。年度という概念は削除されました。
    # 後方互換性のため残していますが、使用しないでください。
    # 代わりに plans_by_farm を使用してください。
    def plans_by_year
      @plans_by_year ||= plans.group_by(&:plan_year)
    end

    def crops_count(plan)
      crops_count_map[plan.id] || 0
    end

    def fields_count(plan)
      fields_count_map[plan.id] || 0
    end

    private

    def plans
      @plans ||= CultivationPlan
                  .plan_type_private
                  .by_user(@current_user)
                  # @deprecated plan_yearは後方互換性のためのみ取得（表示には使用しない）
                  .select(:id, :status, :plan_year, :plan_name, :total_area, :farm_id, :planning_start_date, :planning_end_date, :created_at, :updated_at)
                  .preload(:farm)
                  .recent
    end

    def plan_ids
      @plan_ids ||= plans.map(&:id)
    end

    def crops_count_map
      @crops_count_map ||= begin
        return {} if plan_ids.empty?
        CultivationPlanCrop.where(cultivation_plan_id: plan_ids)
                           .group(:cultivation_plan_id)
                           .count
      end
    end

    def fields_count_map
      @fields_count_map ||= begin
        return {} if plan_ids.empty?
        CultivationPlanField.where(cultivation_plan_id: plan_ids)
                            .group(:cultivation_plan_id)
                            .count
      end
    end
  end
end


