# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmDeletePresenter < Domain::Farm::Ports::FarmDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          undo_data = destroy_output_dto.undo
          undo_json = if undo_data
                        {
                          undo_token: undo_data.undo_token,
                          undo_path: @view.undo_deletion_path(undo_token: undo_data.undo_token),
                          toast_message: @view.translator.t("flash.farms.deleted", name: destroy_output_dto.farm_name),
                          undo_deadline: undo_data.expires_at.iso8601,
                          auto_hide_after: 5000
                        }
          else
                        nil
          end
          @view.render_response(json: { undo: undo_json }, status: :ok)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.render_response(json: { error: I18n.t("farms.flash.no_permission") }, status: :forbidden)
          else
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            @view.render_response(json: { error: msg }, status: :unprocessable_entity)
          end
        end
      end
    end
  end
end
