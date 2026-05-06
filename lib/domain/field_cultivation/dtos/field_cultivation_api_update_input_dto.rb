# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationApiUpdateInputDto
        attr_reader :field_cultivation_id, :start_date, :completion_date, :public_plan

        def initialize(field_cultivation_id:, start_date:, completion_date:, public_plan: false)
          @field_cultivation_id = field_cultivation_id
          @start_date = start_date
          @completion_date = completion_date
          @public_plan = public_plan
        end

        def public_plan?
          @public_plan
        end
      end
    end
  end
end
