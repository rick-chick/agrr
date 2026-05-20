# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Html
        class PrivatePlanIndexHtmlPresenter < Domain::CultivationPlan::Ports::PrivatePlanIndexOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(private_plan_index_dto)
            @view.instance_variable_set(:@private_plan_index, private_plan_index_dto)
          end

          def on_failure(error_dto)
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            @view.redirect_to @view.plans_path, alert: msg
          end
        end
      end
    end
  end
end
