# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserPesticidesInput
        attr_reader :user_id, :region,
                    :reference_crop_id_to_user_crop_id,
                    :reference_pest_id_to_user_pest_id

        # @param user_id [Integer, #to_i]
        # @param region [String, nil]
        # @param reference_crop_id_to_user_crop_id [Hash{Integer=>Integer}]
        # @param reference_pest_id_to_user_pest_id [Hash{Integer=>Integer}]
        def initialize(
          user_id:,
          region: nil,
          reference_crop_id_to_user_crop_id: {},
          reference_pest_id_to_user_pest_id: {}
        )
          @user_id = user_id.to_i
          @region = region.nil? ? nil : region.to_s
          @reference_crop_id_to_user_crop_id = reference_crop_id_to_user_crop_id.freeze
          @reference_pest_id_to_user_pest_id = reference_pest_id_to_user_pest_id.freeze
          freeze
        end
      end
    end
  end
end
