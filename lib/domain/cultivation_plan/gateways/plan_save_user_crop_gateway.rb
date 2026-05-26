# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー作物の検索・作成（狭い永続化ポート）。
      class PlanSaveUserCropGateway
        # @param user_id [Integer]
        # @param source_crop_id [Integer]
        # @return [Object, nil] duck: #id
        def find_by_user_id_and_source_crop_id(user_id:, source_crop_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Object] duck: #id
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end

        # Template-copy 境界: 指定 id の作物 AR
        # @param ids [Array<Integer>]
        # @return [Array<Object>] 呼び出し側 ids の順序を保持
        def list_by_ids(ids:)
          raise NotImplementedError
        end
      end
    end
  end
end
