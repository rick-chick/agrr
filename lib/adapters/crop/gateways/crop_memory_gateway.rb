# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropMemoryGateway < Domain::Crop::Gateways::CropGateway
        def initialize(deletion_undo_gateway:, translator:)
          @deletion_undo_gateway = deletion_undo_gateway
        end

        def list(scope = nil)
          query = scope || ::Crop.all
          query.map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_index_for_user(user)
          list(index_scope_for_user(user))
        end

        def list_user_owned_non_reference_crops_ordered_by_name(user)
          user_owned_non_reference_scope(user).order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_user_owned_non_reference_crops_by_ids(user, ids)
          return [] if ids.blank?

          user_owned_non_reference_scope(user).where(id: ids).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def find_user_non_reference_crop_for_masters!(user, crop_id)
          user_owned_non_reference_scope(user).find(crop_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_user_non_reference_crop_record(user, crop_id)
          user_owned_non_reference_scope(user).find_by(id: crop_id)
        end

        def list_reference_crop_entities(region: nil)
          scope = ::Crop.reference
          scope = scope.where(region: region) if region.present?
          scope.order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def each_reference_crop_for_entry_schedule(region)
          ::Crop.reference
            .yield_self { |s| region.present? ? s.where(region: region) : s }
            .includes(crop_stages: :temperature_requirement)
            .order(:name)
            .find_each { |crop| yield crop }
        end

        def find_reference_crop_for_entry_schedule!(region, crop_id)
          scope = ::Crop.reference
          scope = scope.where(region: region) if region.present?
          scope.includes(crop_stages: :temperature_requirement).find(crop_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        CROP_ASSOCIATION_PRELOAD_INCLUDES = {
          crop_stages: [ :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement ],
          agricultural_tasks: [],
          crop_task_templates: [ :agricultural_task ],
          crop_task_schedule_blueprints: [ :agricultural_task ]
        }.freeze

        def find_authorized_model_for_view(user, id)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.view_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          crop
        end

        def find_authorized_model_for_edit(user, id)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          crop
        end

        def find_authorized_for_view(user, id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_authorized_crop_loaded_bundle!(user, id, for_edit:)
          crop = authorized_crop_record_with_association_preloads!(user, id, for_edit: for_edit)

          Domain::Crop::Dtos::AuthorizedCropLoadedDto.new(
            crop_entity: Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop),
            persisted_crop: crop
          )
        end

        def find_authorized_crop_entity_with_association_preloads(user, id, for_edit:)
          find_authorized_crop_loaded_bundle!(user, id, for_edit: for_edit).crop_entity
        end

        def find_authorized_crop_show_detail(user, crop_id)
          crop = authorized_crop_record_with_association_preloads!(user, crop_id, for_edit: false)
          task_schedule_blueprints = crop.crop_task_schedule_blueprints
                                          .includes(:agricultural_task)
                                          .ordered
          available_tasks = available_agricultural_tasks_for_crop(crop)
          selected_task_ids = crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq

          Domain::Crop::Dtos::CropDetailOutputDto.new(
            crop: Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop),
            persisted_crop: crop,
            task_schedule_blueprints: task_schedule_blueprints,
            available_agricultural_tasks: available_tasks,
            selected_task_ids: selected_task_ids
          )
        end

        def find_model(id)
          find_crop_model!(id)
        end

        def entry_schedule_ordered_stage_rows(crop_id:)
          crop = ::Crop.includes(crop_stages: :temperature_requirement).find(crop_id)
          crop.crop_stages.sort_by(&:order).map do |st|
            tr = st.temperature_requirement
            snap_tr = tr && Domain::CultivationPlan::Interactors::EntrySchedule::TemperatureRequirementSnapshot.new(
              frost_threshold: tr.frost_threshold,
              optimal_min: tr.optimal_min,
              optimal_max: tr.optimal_max,
              base_temperature: tr.base_temperature
            )
            Domain::CultivationPlan::Interactors::EntrySchedule::CropStageSnapshot.new(
              id: st.id,
              name: st.name,
              order: st.order,
              temperature_requirement: snap_tr
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(user, attrs)
          crop = ::Crop.new(h)
          raise StandardError, crop.errors.full_messages.join(", ") unless crop.save

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        end

        def update_for_user(user, id, attrs)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_update(
            user,
            crop.attributes.symbolize_keys,
            attrs
          )
          raise StandardError, crop.errors.full_messages.join(", ") unless crop.update(normalized)

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop.reload)
        end

        def soft_destroy_with_undo(user:, crop_id:, auto_hide_after: 5000, translator:)
          crop = find_crop_model!(crop_id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          if crop.cultivation_plan_crops.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.plan")) }
          end
          if crop.free_crop_plans.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.other")) }
          end
          if crop.pesticides.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.other")) }
          end
          toast_message = translator.t("crops.undo.toast", name: crop.name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            record: crop,
            actor: user,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        def find_by_id(crop_id)
          crop = ::Crop.find(crop_id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Crop not found"
        end

        def create(create_input_dto)
          crop_attributes = {
            name: create_input_dto.name,
            variety: create_input_dto.variety,
            area_per_unit: create_input_dto.area_per_unit,
            revenue_per_area: create_input_dto.revenue_per_area,
            region: create_input_dto.region,
            groups: create_input_dto.groups || []
          }
          crop_attributes[:crop_stages_attributes] = create_input_dto.crop_stages_attributes if create_input_dto.crop_stages_attributes.present?

          crop = ::Crop.new(crop_attributes)
          raise StandardError, crop.errors.full_messages.join(", ") unless crop.save

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        end

        def update(crop_id, update_input_dto)
          crop = ::Crop.find(crop_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:variety] = update_input_dto.variety if !update_input_dto.variety.nil?
          attrs[:area_per_unit] = update_input_dto.area_per_unit if !update_input_dto.area_per_unit.nil?
          attrs[:revenue_per_area] = update_input_dto.revenue_per_area if !update_input_dto.revenue_per_area.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:groups] = update_input_dto.groups if !update_input_dto.groups.nil?
          attrs[:crop_stages_attributes] = update_input_dto.crop_stages_attributes if update_input_dto.crop_stages_attributes.present?

          crop.update(attrs)
          raise StandardError, crop.errors.full_messages.join(", ") if crop.errors.any?

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Crop not found"
        end

        # CropStage methods
        def create_crop_stage(create_dto)
          crop_stage_attributes = attributes_from_crop_stage_dto(create_dto.payload)
          crop_stage_attributes[:crop_id] = create_dto.crop_id

          crop_stage = ::CropStage.new(crop_stage_attributes)
          unless crop_stage.save
            raise StandardError, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage)
        end

        def update_crop_stage(crop_stage_id, update_dto)
          crop_stage = ::CropStage.find(crop_stage_id)
          attrs = attributes_from_crop_stage_dto(update_dto.payload)

          unless crop_stage.update(attrs)
            raise StandardError, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def delete_crop_stage(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          unless crop_stage.destroy
            raise StandardError, crop_stage.errors.full_messages.join(", ")
          end
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def list_crop_stages_by_crop_id(crop_id)
          crop_stages = ::CropStage.where(crop_id: crop_id).order(:order)
          crop_stages.map { |record| crop_stage_entity_from_record(record) }
        end

        def find_crop_stage_by_id(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          crop_stage_entity_from_record(crop_stage)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        # TemperatureRequirement methods
        def find_temperature_requirement(crop_stage_id)
          requirement = ::TemperatureRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          temperature_requirement_entity_from_record(requirement)
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::TemperatureRequirement.new(attrs)
          unless requirement.save
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          temperature_requirement_entity_from_record(requirement)
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          requirement = ::TemperatureRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          temperature_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "TemperatureRequirement not found"
        end

        # ThermalRequirement methods
        def find_thermal_requirement(crop_stage_id)
          requirement = ::ThermalRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          thermal_requirement_entity_from_record(requirement)
        end

        def create_thermal_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::ThermalRequirement.new(attrs)
          unless requirement.save
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          thermal_requirement_entity_from_record(requirement)
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          requirement = ::ThermalRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          thermal_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "ThermalRequirement not found"
        end

        # SunshineRequirement methods
        def find_sunshine_requirement(crop_stage_id)
          requirement = ::SunshineRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          sunshine_requirement_entity_from_record(requirement)
        end

        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::SunshineRequirement.new(attrs)
          unless requirement.save
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          sunshine_requirement_entity_from_record(requirement)
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          requirement = ::SunshineRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          sunshine_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "SunshineRequirement not found"
        end

        # NutrientRequirement methods
        def find_nutrient_requirement(crop_stage_id)
          requirement = ::NutrientRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          nutrient_requirement_entity_from_record(requirement)
        end

        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::NutrientRequirement.new(attrs)
          unless requirement.save
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          nutrient_requirement_entity_from_record(requirement)
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          requirement = ::NutrientRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(", ")
          end
          nutrient_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "NutrientRequirement not found"
        end

        private

        def available_agricultural_tasks_for_crop(crop)
          if !crop.is_reference && crop.user_id.present?
            tasks = ::AgriculturalTask.user_owned.where(user_id: crop.user_id)
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          if crop.is_reference
            tasks = ::AgriculturalTask.reference
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          ::AgriculturalTask.none
        end

        def index_scope_for_user(user)
          if user.admin?
            ::Crop.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Crop.where(user_id: user.id, is_reference: false)
          end
        end

        def user_owned_non_reference_scope(user)
          ::Crop.where(user_id: user.id, is_reference: false)
        end

        def find_crop_model!(id)
          ::Crop.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def crop_stage_entity_from_record(record)
          temperature_req = record.temperature_requirement ? temperature_requirement_entity_from_record(record.temperature_requirement) : nil
          thermal_req = record.thermal_requirement ? thermal_requirement_entity_from_record(record.thermal_requirement) : nil
          sunshine_req = record.sunshine_requirement ? sunshine_requirement_entity_from_record(record.sunshine_requirement) : nil
          nutrient_req = record.nutrient_requirement ? nutrient_requirement_entity_from_record(record.nutrient_requirement) : nil

          Domain::Crop::Entities::CropStageEntity.new(
            id: record.id,
            crop_id: record.crop_id,
            name: record.name,
            order: record.order,
            temperature_requirement: temperature_req,
            thermal_requirement: thermal_req,
            sunshine_requirement: sunshine_req,
            nutrient_requirement: nutrient_req,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def temperature_requirement_entity_from_record(record)
          Domain::Crop::Entities::TemperatureRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            base_temperature: record.base_temperature,
            optimal_min: record.optimal_min,
            optimal_max: record.optimal_max,
            low_stress_threshold: record.low_stress_threshold,
            high_stress_threshold: record.high_stress_threshold,
            frost_threshold: record.frost_threshold,
            sterility_risk_threshold: record.sterility_risk_threshold,
            max_temperature: record.max_temperature
          )
        end

        def thermal_requirement_entity_from_record(record)
          Domain::Crop::Entities::ThermalRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            required_gdd: record.required_gdd
          )
        end

        def sunshine_requirement_entity_from_record(record)
          Domain::Crop::Entities::SunshineRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            minimum_sunshine_hours: record.minimum_sunshine_hours,
            target_sunshine_hours: record.target_sunshine_hours
          )
        end

        def nutrient_requirement_entity_from_record(record)
          Domain::Crop::Entities::NutrientRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            daily_uptake_n: record.daily_uptake_n,
            daily_uptake_p: record.daily_uptake_p,
            daily_uptake_k: record.daily_uptake_k,
            region: record.region
          )
        end

        def attributes_from_crop_stage_dto(dto)
          {
            name: dto[:name],
            order: dto[:order]
          }.compact
        end

        def attributes_from_temperature_requirement_dto(dto)
          {
            base_temperature: dto[:base_temperature],
            optimal_min: dto[:optimal_min],
            optimal_max: dto[:optimal_max],
            low_stress_threshold: dto[:low_stress_threshold],
            high_stress_threshold: dto[:high_stress_threshold],
            frost_threshold: dto[:frost_threshold],
            sterility_risk_threshold: dto[:sterility_risk_threshold],
            max_temperature: dto[:max_temperature]
          }.compact
        end

        def attributes_from_thermal_requirement_dto(dto)
          {
            required_gdd: dto[:required_gdd]
          }.compact
        end

        def attributes_from_sunshine_requirement_dto(dto)
          {
            minimum_sunshine_hours: dto[:minimum_sunshine_hours],
            target_sunshine_hours: dto[:target_sunshine_hours]
          }.compact
        end

        def attributes_from_nutrient_requirement_dto(dto)
          {
            daily_uptake_n: dto[:daily_uptake_n],
            daily_uptake_p: dto[:daily_uptake_p],
            daily_uptake_k: dto[:daily_uptake_k],
            region: dto[:region]
          }.compact
        end

        def authorized_crop_record_with_association_preloads!(user, id, for_edit:)
          crop = ::Crop.includes(CROP_ASSOCIATION_PRELOAD_INCLUDES).find(id)
          allowed = for_edit ? Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id) : Domain::Shared::Policies::CropPolicy.view_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          crop
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
