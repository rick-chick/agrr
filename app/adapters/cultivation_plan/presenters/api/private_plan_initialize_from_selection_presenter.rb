# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class PrivatePlanInitializeFromSelectionPresenter
          include Domain::CultivationPlan::Ports::PrivatePlanInitializeFromSelectionOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(dto)
            @view.render_response(json: { id: dto.id }, status: :created)
          end

          def on_failure(failure)
            @view.render_response(json: { error: failure.message }, status: failure.http_status)
          end
        end
      end
    end
  end
end
