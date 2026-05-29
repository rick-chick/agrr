# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationApiUpdateOutputSnapshot
        attr_reader :field_cultivation_id, :start_date, :completion_date, :cultivation_days

        def initialize(field_cultivation_id:, start_date:, completion_date:, cultivation_days:)
          @field_cultivation_id = field_cultivation_id
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          freeze
        end
      end
    end
  end
end
