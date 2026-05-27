# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserPestsOutput
        attr_reader :user_pest_ids, :skipped_pest_ids, :reference_pest_id_to_user_pest_id

        # @param user_pest_ids [Array<Integer>]
        # @param skipped_pest_ids [Array<Integer>]
        # @param reference_pest_id_to_user_pest_id [Hash{Integer=>Integer}]
        def initialize(
          user_pest_ids:,
          skipped_pest_ids: [],
          reference_pest_id_to_user_pest_id: {}
        )
          @user_pest_ids = Array(user_pest_ids).map(&:to_i).freeze
          @skipped_pest_ids = Array(skipped_pest_ids).map(&:to_i).freeze
          @reference_pest_id_to_user_pest_id = reference_pest_id_to_user_pest_id.freeze
          freeze
        end
      end
    end
  end
end
