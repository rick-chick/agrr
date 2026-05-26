# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserCropsOutput
        attr_reader :user_crop_ids, :skipped_crop_ids, :reference_crop_id_to_user_crop_id,
                    :ref_cpc_id_to_user_crop_id, :stage_copy_pairs, :reference_crop_groups

        # @param user_crop_ids [Array<Integer>] 参照 CPC 順
        # @param skipped_crop_ids [Array<Integer>]
        # @param reference_crop_id_to_user_crop_id [Hash{Integer=>Integer}]
        # @param ref_cpc_id_to_user_crop_id [Hash{Integer=>Integer}]
        # @param stage_copy_pairs [Array<PlanSaveCropStageCopyPair>]
        # @param reference_crop_groups [Array<String>] InteractionRule マッチ用（参照作物名 + groups）
        def initialize(
          user_crop_ids:,
          skipped_crop_ids: [],
          reference_crop_id_to_user_crop_id: {},
          ref_cpc_id_to_user_crop_id: {},
          stage_copy_pairs: [],
          reference_crop_groups: []
        )
          @user_crop_ids = Array(user_crop_ids).map(&:to_i).freeze
          @skipped_crop_ids = Array(skipped_crop_ids).map(&:to_i).freeze
          @reference_crop_id_to_user_crop_id = reference_crop_id_to_user_crop_id.freeze
          @ref_cpc_id_to_user_crop_id = ref_cpc_id_to_user_crop_id.freeze
          @stage_copy_pairs = Array(stage_copy_pairs).freeze
          @reference_crop_groups = Array(reference_crop_groups).freeze
          freeze
        end
      end
    end
  end
end
