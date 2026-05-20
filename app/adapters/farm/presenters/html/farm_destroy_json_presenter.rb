# frozen_string_literal: true

module Adapters
  module Farm
    module Presenters
      module Html
        # HTML マスタ DELETE の JSON 応答 — `FarmDestroyInteractor` の Output port。
        # 成功時は DeletionUndo の DualFormat と同一ペイロード（Undo トークン等のフラット JSON）。
        class FarmDestroyJsonPresenter < Domain::Farm::Ports::FarmDestroyOutputPort
          def initialize(view:, fallback_location:)
            @view = view
            @fallback_location = fallback_location
            @dual = Adapters::DeletionUndo::Presenters::DualFormatResponder.new(
              view: view,
              fallback_location: fallback_location,
              logger: view.respond_to?(:logger) ? view.logger : nil
            )
          end

          def on_success(destroy_output_dto)
            snapshot = Domain::DeletionUndo::ScheduledUndoSnapshot.from(destroy_output_dto.undo)
            @dual.render_scheduled_success(snapshot)
          end

          def on_failure(error_dto)
            if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.render_response(json: { error: I18n.t("farms.flash.no_permission") }, status: :forbidden)
              return
            end

            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            @view.render_response(json: { error: msg }, status: :unprocessable_entity)
          end
        end
      end
    end
  end
end
