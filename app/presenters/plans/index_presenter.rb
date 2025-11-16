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
      @plans_by_year ||= CultivationPlan
                           .plan_type_private
                           .by_user(@current_user)
                           .includes(:farm, field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
                           .recent
                           .group_by(&:plan_year)
    end
  end
end


