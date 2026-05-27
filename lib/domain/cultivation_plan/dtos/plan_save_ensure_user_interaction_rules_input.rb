# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserInteractionRulesInput
        attr_reader :user_id, :region, :reference_crop_groups

        # @param user_id [Integer, #to_i]
        # @param region [String, nil]
        # @param reference_crop_groups [Array<String>]
        def initialize(user_id:, region: nil, reference_crop_groups: [])
          @user_id = user_id.to_i
          @region = region.nil? ? nil : region.to_s
          @reference_crop_groups = Array(reference_crop_groups).map(&:to_s).freeze
          freeze
        end
      end
    end
  end
end
