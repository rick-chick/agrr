# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class CultivationPlanGateway
        def create(create_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def find_existing(farm, user)
          raise NotImplementedError, "Subclasses must implement find_existing"
        end

        def find_farm(farm_id, user)
          raise NotImplementedError, "Subclasses must implement find_farm"
        end

        def find_crops(crop_ids, user)
          raise NotImplementedError, "Subclasses must implement find_crops"
        end

        def destroy(plan_id, user)
          raise NotImplementedError, "Subclasses must implement destroy"
        end
      end
    end
  end
end