# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー圃場の一覧・作成（狭い永続化ポート）。
      class PlanSaveFieldGateway
        # @param farm_id [Integer]
        # @param user_id [Integer]
        # @return [Array<Dtos::PlanSaveFieldSnapshot>]
        def list_by_farm_id(farm_id:, user_id:)
          raise NotImplementedError
        end

        # @param farm_id [Integer]
        # @param user_id [Integer]
        # @param attributes [Hash] :name, :area, :description (optional)
        # @return [Dtos::PlanSaveFieldSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(farm_id:, user_id:, attributes:)
          raise NotImplementedError
        end
      end
    end
  end
end
