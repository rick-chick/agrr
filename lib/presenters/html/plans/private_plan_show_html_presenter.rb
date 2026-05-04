# frozen_string_literal: true

module Presenters
  module Html
    module Plans
      class PrivatePlanShowHtmlPresenter < Domain::CultivationPlan::Ports::PrivatePlanShowOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          @view.instance_variable_set(:@private_plan_show, dto)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_to @view.plans_path, alert: msg
        end
      end
    end
  end
end
