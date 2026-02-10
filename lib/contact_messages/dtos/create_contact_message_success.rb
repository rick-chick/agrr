# frozen_string_literal: true

module ContactMessages
  module Dtos
    class CreateContactMessageSuccess
      attr_reader :contact_message

      def initialize(contact_message:)
        @contact_message = contact_message
      end
    end
  end
end
