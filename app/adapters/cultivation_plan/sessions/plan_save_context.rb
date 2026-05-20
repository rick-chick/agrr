# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Sessions
      # PlanSaveSession 実行中の共有状態（マッパー / ゲートウェイ間で受け渡し）。
      class PlanSaveContext
        attr_accessor :user, :session_data, :result, :farm_reused,
                      :reference_crop_id_to_user_crop_id, :ref_cpc_id_to_user_crop_id,
                      :reference_pest_id_to_user_pest_id, :reference_agricultural_task_id_to_user_task_id,
                      :crop_stage_copy_gateway

        def initialize(user:, session_data:, result:)
          @user = user
          @session_data = session_data
          @result = result
          @farm_reused = false
          @reference_crop_id_to_user_crop_id = {}
          @ref_cpc_id_to_user_crop_id = {}
          @reference_pest_id_to_user_pest_id = {}
          @reference_agricultural_task_id_to_user_task_id = {}
        end
      end
    end
  end
end
