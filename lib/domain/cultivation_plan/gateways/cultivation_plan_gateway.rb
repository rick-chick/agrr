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

        # ID で検索 (Entity または Model を返す)
        def find_by_id(plan_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # phase 更新 proxy (phase_fetching_weather! など)
        def update_phase(plan_id, phase_name, *args)
          raise NotImplementedError, "Subclasses must implement update_phase"
        end
      end
    end
  end
end