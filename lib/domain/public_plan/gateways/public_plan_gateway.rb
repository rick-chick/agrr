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

        def find_crops(crop_ids)
          raise NotImplementedError, "Subclasses must implement find_crops"
        end

        def create(create_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end
      end
    end
  end
end
