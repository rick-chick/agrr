# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanWizardSelectCropHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanWizardSelectCropOutputPort
        def initialize(view:)
          @view = view
        end

        def on_missing_session
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
        end

        def on_missing_farm
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
        end

        def on_invalid_farm_size(farm_id:)
          @view.redirect_to @view.select_crop_public_plans_path(farm_id: farm_id),
                             alert: I18n.t("public_plans.errors.select_farm_size")
        end

        def on_success(dto)
          key = @view.class.session_key
          existing = (@view.session[key] || {}).with_indifferent_access
          @view.session[key] = existing.merge(dto.session_patch).merge(farm_id: dto.farm.id)
          @view.instance_variable_set(:@farm, dto.farm)
          @view.instance_variable_set(
            :@farm_size,
            Adapters::PublicPlan::Mappers::FarmSizeI18nMapper.enrich_one(dto.farm_size)
          )
          @view.instance_variable_set(:@crops, dto.crops)
        end
      end
    end
  end
end
