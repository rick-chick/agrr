# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveUserCropGateway の find / create 戻り値。
      class PlanSaveUserCropSnapshot
        attr_reader :id

        # @param id [Integer, #to_i]
        def initialize(id:)
          @id = id.to_i
          freeze
        end
      end
    end
  end
end
