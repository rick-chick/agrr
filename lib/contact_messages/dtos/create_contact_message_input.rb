# frozen_string_literal: true

module ContactMessages
  module Dtos
    class CreateContactMessageInput
      attr_reader :name, :email, :subject, :message, :source

      def initialize(name:, email:, subject:, message:, source: nil)
        @name = name
        @email = email
        @subject = subject
        @message = message
        @source = source
      end
    end
  end
end