# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSaveReadActiveRecordGateway < Domain::CultivationPlan::Gateways::PublicPlanSaveReadGateway
        def find_header(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          Domain::CultivationPlan::Dtos::PublicPlanSaveHeaderSnapshot.new(
            plan_id: plan.id,
            farm_id: plan.farm_id
          )
        end

        def list_field_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_fields.filter_map do |field|
            Domain::CultivationPlan::Dtos::PublicPlanSaveFieldDatum.from_row(
              name: field.name,
              area: field.area,
              coordinates: [ 35.0, 139.0 ]
            )
          end
        end

        def list_crop_reference_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_crops.includes(:crop).order(:id).map do |cpc|
            crop = cpc.crop
            Domain::CultivationPlan::Dtos::PublicPlanSaveCropReferenceRow.new(
              cultivation_plan_crop_id: cpc.id,
              reference_crop_id: crop.id,
              name: crop.name,
              variety: crop.variety,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area,
              groups: crop.groups,
              region: crop.region
            )
          end
        end

        def list_pest_reference_rows(plan_id:, region:)
          return [] unless ::CultivationPlan.exists?(id: plan_id)

          reference_scope = ::Pest.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope = reference_scope.includes(
            :pest_temperature_profile,
            :pest_thermal_requirement,
            :pest_control_methods,
            :crop_pests
          )

          reference_scope.map { |pest| pest_reference_row_from_record(pest) }
        end

        private

        def pest_reference_row_from_record(pest)
          temperature_profile = if (profile = pest.pest_temperature_profile)
                                  Domain::CultivationPlan::Dtos::PublicPlanSavePestTemperatureProfileRow.new(
                                    base_temperature: profile.base_temperature,
                                    max_temperature: profile.max_temperature
                                  )
                                end

          thermal_requirement = if (thermal = pest.pest_thermal_requirement)
                                  Domain::CultivationPlan::Dtos::PublicPlanSavePestThermalRequirementRow.new(
                                    required_gdd: thermal.required_gdd,
                                    first_generation_gdd: thermal.first_generation_gdd
                                  )
                                end

          control_methods = pest.pest_control_methods.sort_by(&:id).map do |method|
            Domain::CultivationPlan::Dtos::PublicPlanSavePestControlMethodRow.new(
              method_type: method.method_type,
              method_name: method.method_name,
              description: method.description,
              timing_hint: method.timing_hint
            )
          end

          Domain::CultivationPlan::Dtos::PublicPlanSavePestReferenceRow.new(
            reference_pest_id: pest.id,
            name: pest.name,
            name_scientific: pest.name_scientific,
            family: pest.family,
            order: pest.order,
            description: pest.description,
            occurrence_season: pest.occurrence_season,
            region: pest.region,
            linked_reference_crop_ids: pest.crop_pests.map(&:crop_id),
            temperature_profile: temperature_profile,
            thermal_requirement: thermal_requirement,
            control_methods: control_methods
          )
        end
      end
    end
  end
end
