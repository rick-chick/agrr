# frozen_string_literal: true

module Domain
  module Backdoor
    module Dtos
      class BackdoorClearDatabaseFailure
        attr_reader :message

        def initialize(message:)
          @message = message.to_s
        end
      end
    end
  end
end
