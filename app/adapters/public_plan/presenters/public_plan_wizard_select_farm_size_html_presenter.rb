# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanWizardSelectFarmSizeHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanWizardSelectFarmSizeOutputPort
        def initialize(view:, path_helper:)
          @view = view
          @path_helper = path_helper
        end

        def on_missing_farm(alert_i18n_key:)
          @view.redirect_to @view.public_send(@path_helper), alert: I18n.t(alert_i18n_key)
        end

        def on_success(dto)
          key = @view.class.session_key
          @view.session[key] = dto.session_patch
          @view.instance_variable_set(:@farm, dto.farm)
          @view.instance_variable_set(
            :@farm_sizes,
            Adapters::PublicPlan::Mappers::FarmSizeI18nMapper.enrich(dto.farm_sizes)
          )
        end
      end
    end
  end
end
