# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserFieldsInput
        attr_reader :user_id, :farm_id, :farm_reused, :field_data

        # @param user_id [Integer, #to_i]
        # @param farm_id [Integer, #to_i]
        # @param farm_reused [Boolean]
        # @param field_data [Array<PublicPlanSaveFieldDatum>]
        def initialize(user_id:, farm_id:, farm_reused:, field_data: [])
          @user_id = user_id.to_i
          @farm_id = farm_id.to_i
          @farm_reused = farm_reused
          @field_data = Array(field_data).freeze
          freeze
        end
      end
    end
  end
end
