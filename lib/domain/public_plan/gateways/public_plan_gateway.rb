# frozen_string_literal: true

module Domain
  module PublicPlan
    module Gateways
      class PublicPlanGateway
        def find_farm(farm_id)
          raise NotImplementedError, "Subclasses must implement find_farm"
        end

        def find_farm_size(farm_size_id)
          raise NotImplementedError, "Subclasses must implement find_farm_size"
        end

        # @param region [String, nil] 指定時は参照作物かつ当該地域に限定（公開ウィザード用）
        def find_crops(crop_ids, region = nil)
          raise NotImplementedError, "Subclasses must implement find_crops"
        end
      end
    end
  end
end
