# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanWizardSelectCropNoCropsHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def render_failure!(farm:, farm_size:, crops:)
          @view.instance_variable_set(:@farm, farm)
          @view.instance_variable_set(
            :@farm_size,
            Adapters::PublicPlan::Mappers::FarmSizeI18nMapper.enrich_one(farm_size)
          )
          @view.instance_variable_set(:@crops, crops)
          @view.flash.now[:alert] = I18n.t("public_plans.errors.select_crop")
          @view.render :select_crop, status: :unprocessable_entity
        end
      end
    end
  end
end
