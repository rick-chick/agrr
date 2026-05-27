# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveUserPestGateway の find / create 戻り値。
      class PlanSaveUserPestSnapshot
        attr_reader :id, :name

        # @param id [Integer, #to_i]
        # @param name [String, #to_s]
        def initialize(id:, name:)
          @id = id.to_i
          @name = name.nil? ? nil : name.to_s
          freeze
        end
      end
    end
  end
end
