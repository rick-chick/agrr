# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      class Error
        attr_reader :message

        def initialize(message)
          @message = message
        end
      end
    end
  end
end
