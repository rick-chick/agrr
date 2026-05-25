# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: セッション上の参照農場 ID からユーザー農場を確保する入力。
      class PlanSaveEnsureUserFarmInput
        attr_reader :user_id, :reference_farm_id

        # @param user_id [Integer, #to_i]
        # @param reference_farm_id [Integer, #to_i, nil] セッションの farm_id（参照農場）
        def initialize(user_id:, reference_farm_id:)
          @user_id = user_id.to_i
          @reference_farm_id = reference_farm_id.nil? ? nil : reference_farm_id.to_i
          freeze
        end
      end
    end
  end
end
