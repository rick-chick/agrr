# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestDeleteUsageSnapshot
        attr_reader :pesticides_count

        def initialize(pesticides_count:)
          @pesticides_count = pesticides_count
          freeze
        end
      end
    end
  end
end
