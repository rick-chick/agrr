# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class FieldCultivationScheduleSnapshot
        attr_reader :id, :start_date, :crop

        def initialize(id:, start_date:, crop:)
          @id = id
          @start_date = start_date
          @crop = crop
        end
      end
    end
  end
end
