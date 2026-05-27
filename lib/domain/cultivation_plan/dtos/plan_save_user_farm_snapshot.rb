# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveFarmGateway の find_user_farm_by_source / create_user_farm_from_reference 戻り値。
      class PlanSaveUserFarmSnapshot
        attr_reader :id, :name, :region

        def initialize(id:, name:, region:)
          @id = id.to_i
          @name = name.nil? ? nil : name.to_s
          @region = region.nil? ? nil : region.to_s
          freeze
        end
      end
    end
  end
end
