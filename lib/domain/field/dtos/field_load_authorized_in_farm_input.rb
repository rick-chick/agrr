# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldLoadAuthorizedInFarmInput
        attr_reader :farm_id, :field_id

        def initialize(farm_id:, field_id:)
          @farm_id = farm_id
          @field_id = field_id
        end
      end
    end
  end
end
