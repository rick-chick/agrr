# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class CropMastersTaskTemplateIndexPresenter < Domain::Crop::Ports::CropMastersTaskTemplateIndexOutputPort
          def initialize(view:, translator:)
            @view = view
            @translator = translator
          end

          def on_success(rows)
            @view.render_response(json: rows, status: :ok)
          end

          def on_failure(failure_dto)
            case failure_dto.reason
            when :crop_not_found
              @view.render_response(
                json: { error: @translator.t("api.errors.crop_not_found") },
                status: :not_found
              )
            else
              if development_environment?
                raise ArgumentError,
                      "CropMastersTaskTemplateIndexPresenter: unknown failure reason #{failure_dto.reason.inspect}"
              end

              msg = failure_dto.message.presence || "Request could not be processed"
              @view.render_response(json: { error: msg }, status: :unprocessable_entity)
            end
          end

          private

          def development_environment?
            defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
          end
        end
      end
    end
  end
end
