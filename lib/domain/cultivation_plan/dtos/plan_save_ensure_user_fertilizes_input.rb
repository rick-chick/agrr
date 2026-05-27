# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserFertilizesInput
        attr_reader :user_id, :region

        # @param user_id [Integer, #to_i]
        # @param region [String, nil]
        def initialize(user_id:, region: nil)
          @user_id = user_id.to_i
          @region = region.nil? ? nil : region.to_s
          freeze
        end
      end
    end
  end
end
