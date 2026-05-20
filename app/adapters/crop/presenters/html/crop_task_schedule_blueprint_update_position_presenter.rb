# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Html
        class CropTaskScheduleBlueprintUpdatePositionPresenter < Domain::Crop::Ports::CropTaskScheduleBlueprintUpdatePositionOutputPort
          def initialize(view:)
            @view = view
          end

          def on_forbidden
            @view.render json: { error: I18n.t("crops.flash.no_permission") }, status: :forbidden
          end

          def on_bad_request(message)
            @view.render json: { error: message }, status: :bad_request
          end

          def on_success(payload)
            @view.render json: payload, status: :ok
          end

          def on_not_found(error_message)
            @view.render json: { error: error_message }, status: :not_found
          end

          def on_mutation_failure(status, error_message)
            http_status = status == :internal_server_error ? :internal_server_error : :unprocessable_entity
            @view.render json: { error: error_message }, status: http_status
          end
        end
      end
    end
  end
end
