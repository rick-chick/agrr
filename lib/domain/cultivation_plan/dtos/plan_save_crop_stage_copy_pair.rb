# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveCropStageCopyPair
        attr_reader :reference_crop_id, :new_crop_id

        # @param reference_crop_id [Integer]
        # @param new_crop_id [Integer]
        def initialize(reference_crop_id:, new_crop_id:)
          @reference_crop_id = reference_crop_id.to_i
          @new_crop_id = new_crop_id.to_i
          freeze
        end
      end
    end
  end
end
