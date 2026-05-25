# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: ユーザー農場の確保結果（再利用または新規作成後）。
      class PlanSaveEnsureUserFarmOutput
        attr_reader :farm_id, :farm_reused

        # @param farm_id [Integer, #to_i]
        # @param farm_reused [Boolean]
        def initialize(farm_id:, farm_reused:)
          @farm_id = farm_id.to_i
          @farm_reused = farm_reused
          freeze
        end
      end
    end
  end
end
