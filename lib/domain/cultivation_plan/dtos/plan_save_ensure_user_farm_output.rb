# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: ユーザー農場の確保結果（再利用または新規作成後）。
      class PlanSaveEnsureUserFarmOutput
        attr_reader :farm_id, :farm_reused, :farm_region

        # @param farm_id [Integer, #to_i]
        # @param farm_reused [Boolean]
        # @param farm_region [String, nil] マスタコピー等で region フィルタに使う
        def initialize(farm_id:, farm_reused:, farm_region:)
          @farm_id = farm_id.to_i
          @farm_reused = farm_reused
          @farm_region = farm_region.nil? ? nil : farm_region.to_s
          freeze
        end
      end
    end
  end
end
