# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー作物の検索・作成（狭い永続化ポート）。
      class PlanSaveUserCropGateway
        # @param user_id [Integer]
        # @param source_crop_id [Integer]
        # @return [Dtos::PlanSaveUserCropSnapshot, nil]
        def find_by_user_id_and_source_crop_id(user_id:, source_crop_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserCropSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end
      end
    end
  end
end
