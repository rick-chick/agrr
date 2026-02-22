# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationClimateDataInputDto
        attr_reader :field_cultivation_id, :display_start_date, :display_end_date

        def initialize(field_cultivation_id:, display_start_date: nil, display_end_date: nil)
          @field_cultivation_id = field_cultivation_id
          @display_start_date = display_start_date
          @display_end_date = display_end_date
        end
      end
    end
  end
end
