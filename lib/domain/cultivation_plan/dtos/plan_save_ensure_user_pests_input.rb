# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserPestsInput
        attr_reader :user_id, :plan_id, :region, :reference_crop_id_to_user_crop_id

        # @param user_id [Integer, #to_i]
        # @param plan_id [Integer, #to_i]
        # @param region [String, nil]
        # @param reference_crop_id_to_user_crop_id [Hash{Integer=>Integer}]
        def initialize(user_id:, plan_id:, region: nil, reference_crop_id_to_user_crop_id: {})
          @user_id = user_id.to_i
          @plan_id = plan_id.to_i
          @region = region.nil? ? nil : region.to_s
          @reference_crop_id_to_user_crop_id = reference_crop_id_to_user_crop_id.freeze
          freeze
        end

        def reference_crop_ids
          @reference_crop_id_to_user_crop_id.keys
        end
      end
    end
  end
end
