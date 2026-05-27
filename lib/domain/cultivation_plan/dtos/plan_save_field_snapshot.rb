# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveFieldGateway の list / create 戻り値。
      class PlanSaveFieldSnapshot
        attr_reader :id, :name, :area, :farm_id, :user_id

        def initialize(id:, name:, area:, farm_id:, user_id:)
          @id = id.to_i
          @name = name.nil? ? nil : name.to_s
          @area = area
          @farm_id = farm_id.to_i
          @user_id = user_id.to_i
          freeze
        end
      end
    end
  end
end
