# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PrivatePlanDetailMapper
        module_function

        # @param snapshot [Domain::CultivationPlan::Dtos::PrivatePlanReadSnapshot]
        # @param palette_crop_entities [Array<Domain::Crop::Entities::CropEntity>]
        # @return [Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail]
        def to_detail(snapshot:, palette_crop_entities:)
          palette_crops = palette_crop_entities.map do |crop|
            Dtos::PrivatePlanShowPaletteCrop.new(
              id: crop.id,
              name: crop.name,
              variety: crop.variety
            )
          end

          Dtos::PrivateCultivationPlanDetail.new(
            id: snapshot.id,
            display_name: snapshot.display_name,
            farm_display_name: snapshot.farm_display_name,
            total_area: snapshot.total_area,
            field_cultivations_count: snapshot.field_cultivations_count,
            cultivation_plan_fields_count: snapshot.cultivation_plan_fields_count,
            planning_start_date: snapshot.planning_start_date,
            planning_end_date: snapshot.planning_end_date,
            status: snapshot.status,
            field_cultivations: snapshot.field_cultivations,
            cultivation_plan_fields: snapshot.cultivation_plan_fields,
            palette_used_crop_ids: snapshot.palette_used_crop_ids,
            palette_crops: palette_crops
          )
        end
      end
    end
  end
end
