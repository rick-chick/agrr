# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationClimateDataInputDto
        attr_reader :field_cultivation_id

        def initialize(field_cultivation_id:)
          @field_cultivation_id = field_cultivation_id
        end
      end
    end
  end
end
