# frozen_string_literal: true

module ContactMessages
  module Entities
    class ContactMessage
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :id, :name, :email, :subject, :message, :status, :source, :created_at, :sent_at

      validates :email, presence: true, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :message, presence: true, length: { maximum: 5000 }
      validates :source, length: { maximum: 255 }, allow_blank: true
      validates :name, :subject, length: { maximum: 255 }, allow_blank: true

      def sent?
        status == 'sent'
      end

      def failed?
        status == 'failed'
      end

      def queued?
        status == 'queued'
      end
    end
  end
end
