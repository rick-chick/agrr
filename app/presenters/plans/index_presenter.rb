# frozen_string_literal: true

module Plans
  class IndexPresenter
    def initialize(current_user:)
      @current_user = current_user
    end

    def current_year
      @current_year ||= Date.current.year
    end

    def available_years
      @available_years ||= ((current_year - 1)..(current_year + 1)).to_a
    end

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
                  .select(:id, :status, :plan_year, :plan_name, :total_area, :farm_id, :created_at, :updated_at)
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


