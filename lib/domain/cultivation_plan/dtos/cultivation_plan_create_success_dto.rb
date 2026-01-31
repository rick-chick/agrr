# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanCreateSuccessDto
        attr_reader :id, :name, :status

        def initialize(id:, name:, status:)
          @id = id
          @name = name
          @status = status
        end
      end
    end
  end
end