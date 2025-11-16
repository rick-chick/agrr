# frozen_string_literal: true

module Plans
  class ShowPresenter
    def initialize(cultivation_plan:)
      @cultivation_plan = cultivation_plan
      # 最小限の関連のみ事前読込（壊れにくい安全策）
      ActiveRecord::Associations::Preloader.new(
        records: @cultivation_plan,
        associations: [
          :farm,
          :cultivation_plan_fields,
          :field_cultivations,
          :cultivation_plan_crops
        ]
      )
    end

    def plan
      @cultivation_plan
    end

    def farm
      @farm ||= @cultivation_plan.farm
    end

    def fields
      @fields ||= @cultivation_plan.cultivation_plan_fields
    end

    def crops
      @crops ||= @cultivation_plan.cultivation_plan_crops
    end

    def status
      @cultivation_plan.status
    end
  end
end


