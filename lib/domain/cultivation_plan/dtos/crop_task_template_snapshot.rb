# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CropTaskTemplateSnapshot
        attr_reader :agricultural_task

        def initialize(agricultural_task:)
          @agricultural_task = agricultural_task
        end
      end
    end
  end
end
