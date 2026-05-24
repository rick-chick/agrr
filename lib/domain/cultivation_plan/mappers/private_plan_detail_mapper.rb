# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PrivatePlanDetailMapper
        module_function

        # @param rows [Domain::CultivationPlan::Dtos::PrivatePlanReadRowsSnapshot]
        # @param palette_crop_entities [Array<Domain::Crop::Entities::CropEntity>]
        # @return [Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail]
        def to_detail(rows:, palette_crop_entities:)
          palette_crops = palette_crop_entities.map do |crop|
            Dtos::PrivatePlanShowPaletteCrop.new(
              id: crop.id,
              name: crop.name,
              variety: crop.variety
            )
          end

          Dtos::PrivateCultivationPlanDetail.new(
            id: rows.id,
            display_name: rows.display_name,
            farm_display_name: rows.farm_display_name,
            total_area: rows.total_area,
            field_cultivations_count: rows.field_cultivations_count,
            cultivation_plan_fields_count: rows.cultivation_plan_fields_count,
            planning_start_date: rows.planning_start_date,
            planning_end_date: rows.planning_end_date,
            status: rows.status,
            field_cultivations: rows.field_cultivations,
            cultivation_plan_fields: rows.cultivation_plan_fields,
            palette_used_crop_ids: rows.palette_used_crop_ids,
            palette_crops: palette_crops
          )
        end
      end
    end
  end
end
