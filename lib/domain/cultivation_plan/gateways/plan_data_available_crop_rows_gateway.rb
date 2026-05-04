# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data 応答に埋め込む available_crops 行。
      class PlanDataAvailableCropRowsGateway
        # farm_region は公開計画で farm&.region に対応する。private は未使用でもよい。
        # @return [Array<Hash>] [{ id:, name:, variety:, area_per_unit: }, ...]
        def rows(auth:, farm_region: nil)
          raise NotImplementedError
        end
      end
    end
  end
end
