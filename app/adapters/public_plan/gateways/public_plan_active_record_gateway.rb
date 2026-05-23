# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanActiveRecordGateway < Domain::PublicPlan::Gateways::PublicPlanGateway
        def find_by_farm_id(farm_id)
          f = ::Farm.find_by(id: farm_id)
          f && Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(f)
        end

        def list_farm_sizes
          Domain::PublicPlan::Catalog::FarmSizeCatalog.all
        end

        def find_by_farm_size_id(farm_size_id)
          Domain::PublicPlan::Catalog::FarmSizeCatalog.find_by_id(farm_size_id)
        end

        def list_by_ids(crop_ids, region = nil)
          ids = Array(crop_ids).map(&:to_i).uniq.reject(&:zero?)
          return [] if ids.empty?

          rel = ::Crop.where(id: ids, is_reference: true)
          rel = rel.where(region: region) if region.present?
          by_id = rel.index_by(&:id)
          ids.filter_map { |id| by_id[id] }.map { |c| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(c) }
        end
      end
    end
  end
end
