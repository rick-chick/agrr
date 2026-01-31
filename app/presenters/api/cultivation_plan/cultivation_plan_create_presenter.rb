# frozen_string_literal: true

module Api
  module CultivationPlan
    class CultivationPlanCreatePresenter < Domain::CultivationPlan::Ports::CultivationPlanCreateOutputPort
      def initialize(view:)
        @view = view
      end

      def on_success(success_dto)
        @view.render_response(
          json: serialize_success(success_dto),
          status: :created
        )
      end

      def on_failure(failure_dto)
        error_message = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
        @view.render_response(
          json: { error: error_message },
          status: :unprocessable_entity
        )
      end

      private

      def serialize_success(dto)
        {
          id: dto.id,
          name: dto.name,
          status: dto.status
        }
      end
    end
  end
end