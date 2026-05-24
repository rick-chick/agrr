# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanActiveRecordGateway < Domain::CultivationPlan::Gateways::CultivationPlanGateway
        include Adapters::Shared::Concerns::ActiveRecordTransactional

        def initialize(deletion_undo_gateway:, crop_agrr_requirement_builder:)
          @deletion_undo_gateway = deletion_undo_gateway
          @crop_agrr_requirement_builder = crop_agrr_requirement_builder
        end

        def find_with_field_cultivations_for_task_schedule(plan_id)
          plan = ::CultivationPlan.includes(
            field_cultivations: {
              cultivation_plan_crop: {
                crop: {
                  crop_task_templates: :agricultural_task,
                  crop_task_schedule_blueprints: :agricultural_task
                }
              }
            }
          ).find(plan_id)
          Adapters::CultivationPlan::Mappers::TaskScheduleGenerationContextMapper.from_plan_model(
            plan,
            crop_agrr_requirement_builder: @crop_agrr_requirement_builder
          )
        end

        def total_field_area_for_farm(farm_id, user)
          return 0.0 unless ::Farm.find_by(id: farm_id, user_id: user.id)

          ::Field.where(farm_id: farm_id).sum(:area).to_f
        end

        # @param attrs [Domain::CultivationPlan::Dtos::CultivationPlanCreateAttrs]
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def create(attrs:)
          plan_attrs = {
            farm_id: attrs.farm_id,
            user_id: attrs.user_id,
            total_area: attrs.total_area,
            plan_type: attrs.plan_type,
            planning_start_date: attrs.planning_start_date,
            planning_end_date: attrs.planning_end_date
          }
          plan_attrs[:session_id] = attrs.session_id if attrs.session_id.present?
          plan_attrs[:plan_year] = attrs.plan_year unless attrs.plan_year.nil?
          plan_attrs[:plan_name] = attrs.plan_name if attrs.plan_name
          plan_attrs[:status] = attrs.status if attrs.status

          plan = ::CultivationPlan.create!(plan_attrs)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            e.message,
            errors: Domain::Shared::ValidationErrors.from_errors_like(e.record&.errors)
          )
        end

        def find_existing(farm, user)
          plan = ::CultivationPlan.find_by(farm_id: farm.id, user_id: user.id, plan_type: "private")
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        end

        def find_by_farm_id(farm_id, user)
          f = ::Farm.find_by(id: farm_id, user_id: user.id)
          f && Adapters::Farm::Mappers::FarmMapper.farm_entity_from_record(f)
        end

        def list_by_ids(crop_ids, user)
          ::Crop.where(id: crop_ids, user_id: user.id, is_reference: false).map do |c|
            Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(c)
          end
        end

        def find_by_id(plan_id)
          m = ::CultivationPlan.find(plan_id)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(m)
        end

        def find_by_id_for_rest(auth:, plan_id:)
          m = ::Adapters::CultivationPlan::Persistence::PlanScopes.find_record!(auth, plan_id)
          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(m)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        # 栽培計画を削除し、::Adapters::DeletionUndo::Manager を使用して Undo トークンを返す
        #
        # @param plan_id [Integer] 削除する計画のID
        # @param user [User] 削除を実行するユーザー（所有権チェックに使用）
        # @return [DeletionUndoEvent] ::Adapters::DeletionUndo::Manager.schedule が返すイベント
        # @raise [Domain::Shared::Exceptions::RecordNotFound, AssociationInUse, ::Domain::DeletionUndo::Exceptions::DeletionUndoError] 等
        def private_owned_plan_display_name(user:, plan_id:)
          plan_model = find_cultivation_plan_model!(plan_id)
          plan_model.display_name
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan not found"
        end

        def delete(plan_id, user, toast_message:)
          plan_model = find_cultivation_plan_model!(plan_id)

          @deletion_undo_gateway.schedule(
            resource_type: "CultivationPlan",
            resource_id: plan_model.id,
            actor_id: user&.id,
            toast_message: toast_message
          )
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError, Domain::Shared::Exceptions::AssociationInUse
          raise Domain::Shared::Exceptions::AssociationInUse, "Cultivation plan delete failed"
        rescue ::Domain::DeletionUndo::Exceptions::DeletionUndoError
          raise
        end

        def update(plan_id, attrs)
          plan = ::CultivationPlan.find(plan_id)
          raise Domain::Shared::Exceptions::RecordInvalid, plan.errors.full_messages.join(", ") unless plan.update(attrs.to_h.symbolize_keys)

          Adapters::CultivationPlan::Mappers::CultivationPlanEntityMapper.entity_from_model(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_by_plan_id(plan_id)
          plan = ::CultivationPlan.find(plan_id)
          plan.field_cultivations.map { |fc| field_cultivation_entity_from_model(fc) }
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def update_predicted_weather_data(cultivation_plan_id, payload)
          ::CultivationPlan.find(cultivation_plan_id).update!(predicted_weather_data: Domain::WeatherData::Dtos::PredictedWeatherSnapshot.storage_column_value(payload))
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def field_cultivations_present?(plan_id)
          ::CultivationPlan.find(plan_id).field_cultivations.exists?
        end

        def cultivation_plan_crops_with_crop(plan_id)
          rows = ::CultivationPlan.find(plan_id).cultivation_plan_crops.includes(
            crop: { crop_stages: [ :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement ] }
          )
          rows.map do |cpc|
            crop = cpc.crop
            Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrr.new(
              id: cpc.id,
              name: cpc.name,
              crop_id: cpc.crop_id,
              agrr_requirement: @crop_agrr_requirement_builder.build_from(crop),
              revenue_per_area: crop.revenue_per_area,
              crop_name: crop.name
            )
          end
        end

        def clear_field_cultivations(plan_id)
          plan = ::CultivationPlan.find(plan_id)
          plan.field_cultivations.destroy_all
        end

        def create_field_cultivation(plan_id:, attrs:)
          plan = ::CultivationPlan.find(plan_id)
          fc = plan.field_cultivations.create!(attrs.to_active_record_attributes)
          Domain::CultivationPlan::Entities::FieldCultivationEntity.new(
            id: fc.id,
            cultivation_plan_id: fc.cultivation_plan_id,
            cultivation_plan_field_id: fc.cultivation_plan_field_id,
            cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
            area: fc.area,
            start_date: fc.start_date,
            status: fc.status,
            created_at: fc.created_at,
            updated_at: fc.updated_at
          )
        end

        def upsert_cultivation_plan_field(plan_id:, name:, area:, daily_fixed_cost:)
          plan = ::CultivationPlan.find(plan_id)
          field = plan.cultivation_plan_fields.find_or_create_by!(name: name) do |f|
            f.area = area
            f.daily_fixed_cost = daily_fixed_cost
          end
          field.id
        end

        def find_crop_id!(plan_id, crop_id)
          plan = ::CultivationPlan.find(plan_id)
          cpc = plan.cultivation_plan_crops.find_by(crop_id: crop_id)
          return cpc.id if cpc

          available = plan.cultivation_plan_crops.pluck(:crop_id, :name)
          raise Domain::CultivationPlan::Errors::CultivationPlanCropMissingError,
                "CultivationPlanCrop not found for crop_id: #{crop_id}. This indicates a data integrity issue. Available CultivationPlanCrops: #{available.inspect}"
        end

        def apply_optimization_result(plan_id:, attrs:)
          ::CultivationPlan.find(plan_id).update!(attrs.to_active_record_attributes)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def session_data_for_public_plan_save_from_plan_id(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          {
            plan_id: plan.id,
            farm_id: plan.farm_id,
            crop_ids: plan.crops.pluck(:id),
            field_data: plan.cultivation_plan_fields.map do |field|
              {
                name: field.name,
                area: field.area,
                coordinates: [ 35.0, 139.0 ]
              }
            end
          }
        end

        private

        def normalize_farm_for_plan!(farm)
          return farm if farm.is_a?(::Farm)

          ::Farm.find(farm.id)
        end

        def normalize_user_for_plan(user)
          return nil if user.nil?
          return user if user.is_a?(::User)

          ::User.find(user.id)
        end

        def normalize_crops_for_plan!(crops)
          return [] if crops.blank?
          return crops if crops.first.is_a?(::Crop)

          crops.map { |c| ::Crop.find(c.id) }
        end

        def find_cultivation_plan_model!(plan_id)
          ::CultivationPlan.find(plan_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def field_cultivation_entity_from_model(fc)
          Domain::CultivationPlan::Entities::FieldCultivationEntity.new(
            id: fc.id,
            cultivation_plan_id: fc.cultivation_plan_id,
            cultivation_plan_field_id: fc.cultivation_plan_field_id,
            cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
            area: fc.area,
            start_date: fc.start_date,
            status: fc.status,
            created_at: fc.created_at,
            updated_at: fc.updated_at
          )
        end

      end
    end
  end
end
