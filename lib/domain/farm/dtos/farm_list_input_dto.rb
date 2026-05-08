# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmListInputDto
        attr_reader :is_admin

        def initialize(is_admin: false)
          @is_admin = is_admin
        end
      end
    end
  end
end
