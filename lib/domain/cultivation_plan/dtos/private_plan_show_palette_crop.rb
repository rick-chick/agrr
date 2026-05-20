# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画 show の作物パレット 1 行。ActiveRecord は含めない。
      class PrivatePlanShowPaletteCrop
        attr_reader :id, :name, :variety

        # @param id [Integer]
        # @param name [String]
        # @param variety [String, nil]
        def initialize(id:, name:, variety:)
          @id = id
          @name = name
          @variety = variety
        end
      end
    end
  end
end
