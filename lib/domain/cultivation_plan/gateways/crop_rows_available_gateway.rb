# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 計画データ API の available_crops 行（認可は呼び出し側）。
      class CropRowsAvailableGateway
        # @param auth [Object] 認可済みセッションコンテキスト
        # @param farm_region [String, nil] 公開計画で farm.region に相当
        # @return [Array<Domain::CultivationPlan::Dtos::CropRowsAvailableRow>]
        def list_by_farm_region(auth:, farm_region: nil)
          raise NotImplementedError
        end
      end
    end
  end
end
