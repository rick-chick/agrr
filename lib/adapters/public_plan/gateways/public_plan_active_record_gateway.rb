# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanActiveRecordGateway < Domain::PublicPlan::Gateways::PublicPlanGateway
        def find_farm(farm_id)
          f = ::Farm.find_by(id: farm_id)
          f && Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(f)
        end

        def find_farm_size(farm_size_id)
          farm_sizes = [
            { id: "home_garden", area_sqm: 30 },
            { id: "community_garden", area_sqm: 50 },
            { id: "rental_farm", area_sqm: 300 }
          ]

          farm_sizes.find do |size|
            size[:id].to_s == farm_size_id.to_s || size[:area_sqm] == farm_size_id.to_i
          end
        end

        def find_crops(crop_ids)
          ::Crop.where(id: crop_ids).map { |c| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(c) }
        end
      end
    end
  end
end
