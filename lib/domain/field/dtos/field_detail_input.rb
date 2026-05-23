# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldDetailInput
        attr_reader :field_id, :farm_id

        # @param field_id [Integer, String]
        # @param farm_id [Integer, String, nil] route scope for HTML redirect on failure
        def initialize(field_id:, farm_id: nil)
          @field_id = field_id.to_i
          @farm_id = farm_id.nil? ? nil : farm_id.to_i
        end
      end
    end
  end
end
