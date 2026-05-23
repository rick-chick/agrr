# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestDeleteUsage
        attr_reader :pesticides_count

        def initialize(pesticides_count:)
          @pesticides_count = pesticides_count
        end
      end
    end
  end
end
