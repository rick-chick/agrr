# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropMastersTaskTemplateDestroyApiPresenter < Domain::Crop::Ports::CropMastersTaskTemplateDestroyOutputPort
        ERRORS_SCOPE = %i[controllers api masters crops agricultural_tasks errors].freeze

        def initialize(view:, translator:)
          @view = view
          @translator = translator
        end

        def on_success
          @view.head :no_content
        end

        def on_failure(failure_dto)
          case failure_dto.reason
          when :association_not_found
            @view.render_response(
              json: { error: t_error(:association_not_found) },
              status: :not_found
            )
          else
            if development_environment?
              raise ArgumentError,
                    "CropMastersTaskTemplateDestroyPresenter: unknown failure reason #{failure_dto.reason.inspect}"
            end

            msg = failure_dto.message.presence || t_error(:unexpected)
            @view.render_response(json: { error: msg }, status: :unprocessable_entity)
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
      end
    end
  end
end
