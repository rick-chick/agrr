# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Html
        class PrivatePlanSelectCropHtmlPresenter < Domain::CultivationPlan::Ports::PrivatePlanSelectCropContextOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(dto)
            @view.instance_variable_set(:@farm, dto.farm)
            @view.instance_variable_set(:@plan_name, dto.plan_name)
            @view.instance_variable_set(:@crops, dto.crops)
            @view.instance_variable_set(:@total_area, dto.total_area)
          end

          def on_failure(error_dto)
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            @view.redirect_to @view.new_plan_path, alert: msg
          end
        end
      end
    end
  end
end
