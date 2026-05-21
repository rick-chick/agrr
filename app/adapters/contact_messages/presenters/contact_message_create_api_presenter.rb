# frozen_string_literal: true

module Adapters
  module ContactMessages
    module Presenters
      class ContactMessageCreateApiPresenter < ::Domain::ContactMessages::Ports::CreateContactMessageOutputPort
        INTERNAL_SERVER_ERROR_MESSAGE = "Internal server error".freeze

        def initialize(view:)
          @view = view
        end

        # success_dto can be an object that responds to :contact_message (e.g. OpenStruct from interactor)
        # or a ContactMessage entity directly.
        def on_success(success_dto)
          cm = success_dto.respond_to?(:contact_message) ? success_dto.contact_message : success_dto

          @view.render_response(
            json: serialize_contact_message(cm),
            status: :created
          )
        end

        # failure_dto may contain ActiveModel::Errors under :errors or be a simple error/message string/object
        def on_failure(failure_dto)
          if failure_dto.respond_to?(:rate_limit?) && failure_dto.rate_limit?
            @view.render_response(
              json: { error: failure_dto.message },
              status: :too_many_requests
            )
            return
          end

          if failure_dto.respond_to?(:recaptcha?) && failure_dto.recaptcha?
            @view.render_response(
              json: { error: failure_dto.message },
              status: :forbidden
            )
            return
          end

          if failure_dto.respond_to?(:errors) && failure_dto.errors.respond_to?(:messages)
            @view.render_response(
              json: { error: "Validation failed", field_errors: failure_dto.errors.messages },
              status: :unprocessable_entity
            )
          else
            @view.render_response(
              json: { error: INTERNAL_SERVER_ERROR_MESSAGE },
              status: :internal_server_error
            )
          end
        end

        private

        def serialize_contact_message(cm)
          {
            id: cm.id,
            status: cm.status,
            created_at: cm.created_at&.iso8601,
            sent_at: cm.sent_at&.iso8601
          }
        end
      end
    end
  end
end
