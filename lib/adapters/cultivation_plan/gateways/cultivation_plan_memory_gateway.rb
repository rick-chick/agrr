# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanMemoryGateway < Domain::CultivationPlan::Gateways::CultivationPlanGateway
        def create(create_dto)
          # CultivationPlanCreatorを使って計画を作成
          creator = CultivationPlanCreator.new(
            farm: create_dto.farm,
            total_area: create_dto.total_area,
            crops: create_dto.crops,
            user: create_dto.user,
            plan_type: 'private',
            plan_name: create_dto.plan_name,
            planning_start_date: Date.current.beginning_of_year,
            planning_end_date: Date.new(Date.current.year + 1, 12, 31)
          )

          result = creator.call
          unless result.success?
            raise StandardError, result.errors.join(', ')
          end

          result
        end

        def find_existing(farm, user)
          ::CultivationPlan.where(farm: farm, user: user, plan_type: 'private').first
        end

        def find_farm(farm_id, user)
          ::Farm.find_by(id: farm_id, user: user)
        end

        def find_crops(crop_ids, user)
          ::Crop.where(id: crop_ids, user: user, is_reference: false).to_a
        end
      end
    end
  end
end