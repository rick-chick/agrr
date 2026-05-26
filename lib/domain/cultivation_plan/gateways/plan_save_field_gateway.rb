# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー圃場の一覧・作成（狭い永続化ポート）。
      class PlanSaveFieldGateway
        # @param farm_id [Integer]
        # @param user_id [Integer]
        # @return [Array<Object>] duck: #id, #name, #area, #farm_id, #user_id
        def list_by_farm_id(farm_id:, user_id:)
          raise NotImplementedError
        end

        # @param farm_id [Integer]
        # @param user_id [Integer]
        # @param attributes [Hash] :name, :area, :description (optional)
        # @return [Object] duck: #id
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(farm_id:, user_id:, attributes:)
          raise NotImplementedError
        end

        # Template-copy 境界: 指定 id の圃場 AR（ユーザー所有に限定）
        # @param ids [Array<Integer>]
        # @param user_id [Integer]
        # @return [Array<Object>] 呼び出し側 ids の順序を保持
        def list_by_ids(ids:, user_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
