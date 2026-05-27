# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveUserAgriculturalTaskGateway の find / create 戻り値。
      class PlanSaveUserAgriculturalTaskSnapshot
        attr_reader :id, :name

        def initialize(id:, name:)
          @id = id.to_i
          @name = name.nil? ? nil : name.to_s
          freeze
        end
      end
    end
  end
end
