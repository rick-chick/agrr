# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Presenters
      class FieldCultivationApiUpdateApiPresenter < Domain::FieldCultivation::Ports::FieldCultivationApiUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          payload = {
            success: true,
            field_cultivation: {
              id: dto.field_cultivation_id,
              start_date: dto.start_date,
              completion_date: dto.completion_date
            }
          }
          if dto.public_plan_response?
            payload[:message] = dto.message
            payload[:field_cultivation][:cultivation_days] = dto.cultivation_days
          end
          @view.render_response(json: payload, status: :ok)
        end

        def on_failure(failure)
          case failure
          when Domain::Shared::Exceptions::RecordInvalid
            @view.render_response(
              json: {
                success: false,
                errors: failure.flatten_error_messages
              },
              status: :unprocessable_entity
            )
          when Domain::Shared::Dtos::Error
            @view.render_response(json: { error: failure.message }, status: :not_found)
          else
            msg = failure.respond_to?(:message) ? failure.message : failure.to_s
            @view.render_response(json: { error: msg }, status: :internal_server_error)
          end
        end
      end
    end
  end
end
