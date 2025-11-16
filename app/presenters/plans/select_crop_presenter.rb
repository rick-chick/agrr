# frozen_string_literal: true

module Plans
  class SelectCropPresenter
    def initialize(current_user:, plan_year:, farm_id:)
      @current_user = current_user
      @plan_year = Integer(plan_year)
      @farm = @current_user.farms.find(farm_id)
    end

    def plan_year
      @plan_year
    end

    def farm
      @farm
    end

    def plan_name
      @plan_name ||= @farm.name
    end

    def crops
      @crops ||= @current_user.crops.where(is_reference: false).order(:name)
    end

    def fields
      @fields ||= @farm.fields.order(:name)
    end

    def total_area
      @total_area ||= fields.sum(:area)
    end
  end
end


