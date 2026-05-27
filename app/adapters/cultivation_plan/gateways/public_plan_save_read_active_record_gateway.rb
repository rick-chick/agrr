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

        def list_pesticide_reference_rows(region:)
          reference_scope = ::Pesticide.reference.includes(
            :pesticide_usage_constraint,
            :pesticide_application_detail
          )
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map { |pesticide| pesticide_reference_row_from_record(pesticide) }
        end

        def list_fertilize_reference_rows(region:)
          reference_scope = ::Fertilize.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map { |fertilize| fertilize_reference_row_from_record(fertilize) }
        end

        def exists_fertilize_name?(name:)
          ::Fertilize.exists?(name: name)
        end

        def list_agricultural_task_reference_rows(region:)
          reference_scope = ::AgriculturalTask.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.includes(crop_task_templates: :crop).map do |task|
            agricultural_task_reference_row_from_record(task)
          end
        end

        def list_interaction_rule_reference_rows(region:)
          reference_scope = ::InteractionRule.reference.where(rule_type: "continuous_cultivation")
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map { |rule| interaction_rule_reference_row_from_record(rule) }
        end

        private

        def agricultural_task_reference_row_from_record(task)
          template_links = task.crop_task_templates.map do |template|
            Domain::CultivationPlan::Dtos::PublicPlanSaveCropTaskTemplateLinkRow.new(
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

          linked_crop_ids = template_links.map(&:reference_crop_id).uniq

          Domain::CultivationPlan::Dtos::PublicPlanSaveAgriculturalTaskReferenceRow.new(
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
            linked_reference_crop_ids: linked_crop_ids,
            template_links: template_links
          )
        end

        def pesticide_reference_row_from_record(pesticide)
          usage_constraint = if (constraint = pesticide.pesticide_usage_constraint)
                               Domain::CultivationPlan::Dtos::PublicPlanSavePesticideUsageConstraintRow.new(
                                 min_temperature: constraint.min_temperature,
                                 max_temperature: constraint.max_temperature,
                                 max_wind_speed_m_s: constraint.max_wind_speed_m_s,
                                 max_application_count: constraint.max_application_count,
                                 harvest_interval_days: constraint.harvest_interval_days,
                                 other_constraints: constraint.other_constraints
                               )
                             end

          application_detail = if (detail = pesticide.pesticide_application_detail)
                                 Domain::CultivationPlan::Dtos::PublicPlanSavePesticideApplicationDetailRow.new(
                                   dilution_ratio: detail.dilution_ratio,
                                   amount_per_m2: detail.amount_per_m2,
                                   amount_unit: detail.amount_unit,
                                   application_method: detail.application_method
                                 )
                               end

          Domain::CultivationPlan::Dtos::PublicPlanSavePesticideReferenceRow.new(
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

        def fertilize_reference_row_from_record(fertilize)
          Domain::CultivationPlan::Dtos::PublicPlanSaveFertilizeReferenceRow.new(
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

        def interaction_rule_reference_row_from_record(rule)
          Domain::CultivationPlan::Dtos::PublicPlanSaveInteractionRuleReferenceRow.new(
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
      end
    end
  end
end
