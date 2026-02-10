# frozen_string_literal: true

require_relative '../../../domain/contact_messages/entities/contact_message'
module Adapters
  module ContactMessages
    module Gateways
      class ContactMessageActiveRecordGateway < ::ContactMessages::Gateways::ContactMessageGateway
        def initialize(destination_email:, delivery_job: ContactMessageDeliveryJob)
          @destination_email = destination_email
          @delivery_job = delivery_job
        end

        def find_by_id(id)
          record = ::ContactMessage.find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end

        # create_dto: ContactMessages::Dtos::CreateContactMessageInput
        def create(create_dto)
          record = ::ContactMessage.new(
            name: create_dto.name,
            email: create_dto.email,
            subject: create_dto.subject,
            message: create_dto.message,
            source: create_dto.source,
            status: 'queued'
          )

          # save! will raise ActiveRecord::RecordInvalid on validation errors
          record.save!

          enqueue_delivery_job(record)

          entity_from_record(record)
        end

        private

        def entity_from_record(record)
          ::ContactMessages::Entities::ContactMessage.new(
            id: record.id,
            name: record.name,
            email: record.email,
            subject: record.subject,
            message: record.message,
            status: record.status,
            source: record.source,
            created_at: record.created_at,
            sent_at: record.sent_at
          )
        end

        def enqueue_delivery_job(record)
          @delivery_job.perform_later(record.id, @destination_email)
        end
      end
    end
  end
end

