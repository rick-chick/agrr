# frozen_string_literal: true

module Domain
  module PublicPlan
    module Gateways
      class PublicPlanGateway
        def find_by_farm_id(farm_id)
          raise NotImplementedError, "Subclasses must implement find_by_farm_id"
        end

        def find_by_farm_size_id(farm_size_id)
          raise NotImplementedError, "Subclasses must implement find_by_farm_size_id"
        end

        # @param region [String, nil] 指定時は参照作物かつ当該地域に限定（公開ウィザード用）
        def list_by_ids(crop_ids, region = nil)
          raise NotImplementedError, "Subclasses must implement list_by_ids"
        end
      end
    end
  end
end
