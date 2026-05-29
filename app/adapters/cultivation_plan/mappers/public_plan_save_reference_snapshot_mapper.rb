# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # ActiveRecord → PublicPlanSave* row DTOs（domain snapshot / row）。
      module PublicPlanSaveReferenceSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        def header_from_model(plan)
          Dtos::PublicPlanSaveHeaderSnapshot.new(plan_id: plan.id, farm_id: plan.farm_id)
        end

        def field_row_from_model(field)
          Dtos::PublicPlanSaveFieldDatum.from_row(
            name: field.name,
            area: field.area,
            coordinates: [ 35.0, 139.0 ]
          )
        end

        def crop_reference_row_from_models(cpc, crop)
          Dtos::PublicPlanSaveCropReferenceRow.new(
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

        def interaction_rule_row_from_model(rule)
          Dtos::PublicPlanSaveInteractionRuleReferenceRow.new(
            reference_interaction_rule_id: rule.id,
            rule_type: rule.rule_type,
            source_group: rule.source_group,
            target_group: rule.target_group,
            impact_ratio: rule.impact_ratio,
            is_directional: rule.is_directional,
            region: rule.region,
            description: rule.description
          )
        end

        def fertilize_row_from_model(fertilize)
          Dtos::PublicPlanSaveFertilizeReferenceRow.new(
            reference_fertilize_id: fertilize.id,
            name: fertilize.name,
            n: fertilize.n,
            p: fertilize.p,
            k: fertilize.k,
            description: fertilize.description,
            package_size: fertilize.package_size,
            region: fertilize.region
          )
        end

        def pesticide_row_from_model(pesticide)
          constraint = pesticide.pesticide_usage_constraint
          usage_constraint = constraint && Dtos::PublicPlanSavePesticideUsageConstraintRow.new(
            min_temperature: constraint.min_temperature,
            max_temperature: constraint.max_temperature,
            max_wind_speed_m_s: constraint.max_wind_speed_m_s,
            max_application_count: constraint.max_application_count,
            harvest_interval_days: constraint.harvest_interval_days,
            other_constraints: constraint.other_constraints
          )

          detail = pesticide.pesticide_application_detail
          application_detail = detail && Dtos::PublicPlanSavePesticideApplicationDetailRow.new(
            dilution_ratio: detail.dilution_ratio,
            amount_per_m2: detail.amount_per_m2,
            amount_unit: detail.amount_unit,
            application_method: detail.application_method
          )

          Dtos::PublicPlanSavePesticideReferenceRow.new(
            reference_pesticide_id: pesticide.id,
            reference_crop_id: pesticide.crop_id,
            reference_pest_id: pesticide.pest_id,
            name: pesticide.name,
            active_ingredient: pesticide.active_ingredient,
            description: pesticide.description,
            region: pesticide.region,
            usage_constraint: usage_constraint,
            application_detail: application_detail
          )
        end

        def pest_row_from_model(pest)
          profile = pest.pest_temperature_profile
          temperature_profile = profile && Dtos::PublicPlanSavePestTemperatureProfileRow.new(
            base_temperature: profile.base_temperature,
            max_temperature: profile.max_temperature
          )

          thermal = pest.pest_thermal_requirement
          thermal_requirement = thermal && Dtos::PublicPlanSavePestThermalRequirementRow.new(
            required_gdd: thermal.required_gdd,
            first_generation_gdd: thermal.first_generation_gdd
          )

          control_methods = pest.pest_control_methods.sort_by(&:id).map do |method|
            Dtos::PublicPlanSavePestControlMethodRow.new(
              method_type: method.method_type,
              method_name: method.method_name,
              description: method.description,
              timing_hint: method.timing_hint
            )
          end

          Dtos::PublicPlanSavePestReferenceRow.new(
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

        def agricultural_task_row_from_model(task)
          template_links = task.crop_task_templates.map do |template|
            Dtos::PublicPlanSaveCropTaskTemplateLinkRow.new(
              reference_crop_id: template.crop_id,
              name: template.name,
              description: template.description,
              time_per_sqm: template.time_per_sqm,
              weather_dependency: template.weather_dependency,
              required_tools: template.required_tools,
              skill_level: template.skill_level,
              task_type: template.task_type,
              task_type_id: template.task_type_id,
              is_reference: template.is_reference
            )
          end

          Dtos::PublicPlanSaveAgriculturalTaskReferenceRow.new(
            reference_agricultural_task_id: task.id,
            name: task.name,
            description: task.description,
            time_per_sqm: task.time_per_sqm,
            weather_dependency: task.weather_dependency,
            required_tools: task.required_tools,
            skill_level: task.skill_level,
            task_type: task.task_type,
            task_type_id: task.task_type_id,
            region: task.region,
            linked_reference_crop_ids: template_links.map(&:reference_crop_id).uniq,
            template_links: template_links
          )
        end
      end
    end
  end
end
