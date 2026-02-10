module ContactMessages
  class DestinationEmailNotConfiguredError < StandardError
    def initialize
      super('CONTACT_DESTINATION_EMAIL is not configured for contact message delivery')
    end
  end
end
