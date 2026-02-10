module ContactMessages
  module Errors
    class DestinationEmailNotConfiguredError < StandardError
      def initialize
        super('CONTACT_DESTINATION_EMAIL is not configured for contact message delivery')
      end
    end
  end
  # Backwards-compatibility: some places reference ContactMessages::DestinationEmailNotConfiguredError
  # so alias the constant at the ContactMessages namespace level.
  DestinationEmailNotConfiguredError = Errors::DestinationEmailNotConfiguredError
end
