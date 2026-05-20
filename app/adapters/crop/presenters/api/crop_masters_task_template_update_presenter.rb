# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Api
        class CropMastersTaskTemplateUpdatePresenter < Domain::Crop::Ports::CropMastersTaskTemplateUpdateOutputPort
          ERRORS_SCOPE = %i[controllers api masters crops agricultural_tasks errors].freeze

          def initialize(view:, translator:)
            @view = view
            @translator = translator
          end

          def on_success(row)
            @view.render_response(json: row, status: :ok)
          end

          def on_failure(failure_dto)
            case failure_dto.reason
            when :validation_failed
              @view.render_response(json: { errors: failure_dto.errors || [] }, status: :unprocessable_entity)
            when :association_not_found
              render_error(t_error(:association_not_found), :not_found)
            else
              if development_environment?
                raise ArgumentError,
                      "CropMastersTaskTemplateUpdatePresenter: unknown failure reason #{failure_dto.reason.inspect}"
              end

              msg = failure_dto.message.presence || t_error(:unexpected)
              render_error(msg, :unprocessable_entity)
            end
          end

          private

          def development_environment?
            defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
          end

          def t_error(key)
            @translator.t(key, scope: ERRORS_SCOPE, default: FALLBACK.fetch(key))
          end

          FALLBACK = {
            association_not_found: "AgriculturalTask association not found",
            unexpected: "Request could not be processed"
          }.freeze

          def render_error(message, status)
            @view.render_response(json: { error: message }, status: status)
          end
        end
      end
    end
  end
end
