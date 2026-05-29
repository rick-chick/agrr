# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSaveReadActiveRecordGateway < Domain::CultivationPlan::Gateways::PublicPlanSaveReadGateway
        def find_header_snapshot(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          Mappers::PublicPlanSaveReferenceSnapshotMapper.header_from_model(plan)
        end

        def list_field_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_fields.map do |field|
            Mappers::PublicPlanSaveReferenceSnapshotMapper.field_row_from_model(field)
          end
        end

        def list_crop_reference_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_crops.includes(:crop).order(:id).map do |cpc|
            Mappers::PublicPlanSaveReferenceSnapshotMapper.crop_reference_row_from_models(cpc, cpc.crop)
          end
        end

        def list_pest_reference_rows(plan_id:, region:)
          return [] unless ::CultivationPlan.exists?(id: plan_id)

          reference_scope = ::Pest.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.includes(
            :pest_temperature_profile,
            :pest_thermal_requirement,
            :pest_control_methods,
            :crop_pests
          ).map { |pest| Mappers::PublicPlanSaveReferenceSnapshotMapper.pest_row_from_model(pest) }
        end

        def list_pesticide_reference_rows(region:)
          reference_scope = ::Pesticide.reference.includes(
            :pesticide_usage_constraint,
            :pesticide_application_detail
          )
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map do |pesticide|
            Mappers::PublicPlanSaveReferenceSnapshotMapper.pesticide_row_from_model(pesticide)
          end
        end

        def list_fertilize_reference_rows(region:)
          reference_scope = ::Fertilize.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map do |fertilize|
            Mappers::PublicPlanSaveReferenceSnapshotMapper.fertilize_row_from_model(fertilize)
          end
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
            Mappers::PublicPlanSaveReferenceSnapshotMapper.agricultural_task_row_from_model(task)
          end
        end

        def list_interaction_rule_reference_rows(region:)
          reference_scope = ::InteractionRule.reference
          if region.present?
            reference_scope = reference_scope.where(region: [ region, nil ])
          end

          reference_scope.order(:id).map do |rule|
            Mappers::PublicPlanSaveReferenceSnapshotMapper.interaction_rule_row_from_model(rule)
          end
        end
      end
    end
  end
end
