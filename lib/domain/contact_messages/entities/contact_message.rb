# frozen_string_literal: true

module Domain
  module ContactMessages
    module Entities
      class ContactMessage
        attr_accessor :id, :name, :email, :subject, :message, :status, :source, :created_at, :sent_at

        def initialize(attributes = {})
          @errors = Domain::Shared::ValidationErrors.new
          assign_attributes(attributes)
        end

        def errors
          @errors ||= Domain::Shared::ValidationErrors.new
        end

        def valid?
          @errors = Domain::Shared::ValidationErrors.new
          validate_email
          validate_message
          validate_optional_field_lengths
          @errors.empty?
        end

        def sent?
          status == "sent"
        end

        def failed?
          status == "failed"
        end

        def queued?
          status == "queued"
        end

        private

        def assign_attributes(attributes)
          attributes.each do |key, value|
            writer = "#{key}="
            public_send(writer, value) if respond_to?(writer, true)
          end
        end

        def validate_email
          if Domain::Shared.blank?(email)
            @errors.add(:email, "can't be blank")
          elsif email.to_s.length > 255
            @errors.add(:email, "is too long (maximum is 255 characters)")
          elsif email.to_s !~ URI::MailTo::EMAIL_REGEXP
            @errors.add(:email, "is invalid")
          end
        end

        def validate_message
          if Domain::Shared.blank?(message)
            @errors.add(:message, "can't be blank")
          elsif message.to_s.length > 5000
            @errors.add(:message, "is too long (maximum is 5000 characters)")
          end
        end

        def validate_optional_field_lengths
          %i[name subject source].each do |attr|
            value = public_send(attr)
            next if Domain::Shared.blank?(value)
            next if value.to_s.length <= 255

            @errors.add(attr, "is too long (maximum is 255 characters)")
          end
        end
      end
    end
  end
end
