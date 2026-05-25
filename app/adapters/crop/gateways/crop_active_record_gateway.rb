# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropActiveRecordGateway < Domain::Crop::Gateways::CropGateway
        include CropStageRequirementEntitySupport
        def initialize(deletion_undo_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_user_owned_non_reference_crops_ordered_by_name(user)
          user_owned_non_reference_scope(user).order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def find_reference_crop_record_for_public_plan_add_crop(crop_id)
          return nil if crop_id.blank?

          ::Crop.reference.find_by(id: crop_id.to_i)
        end

        def list_reference_crop_entities(region: nil)
          scope = ::Crop.reference
          scope = scope.where(region: region) if region.present?
          scope.order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_by_user_id(user_id:, region: nil)
          scope = ::Crop.where(is_reference: false, user_id: user_id)
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
          crop_task_schedule_blueprints: [ :agricultural_task ],
          pests: []
        }.freeze

        def masters_crop_agricultural_task_templates_index_rows(crop_id:)
          crop = find_crop_model!(crop_id.to_i)
          crop.crop_task_templates.includes(:agricultural_task).map { |t| masters_crop_task_template_api_row(t) }
        end

        def update_masters_crop_task_template_for_api(crop_id:, template_id:, attributes:)
          crop = find_crop_model!(crop_id.to_i)
          tpl = crop.crop_task_templates.find(template_id.to_i)
          if tpl.update(attributes)
            { ok: true, row: masters_crop_task_template_api_row(tpl.reload) }
          else
            { ok: false, errors: tpl.errors.full_messages }
          end
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "AgriculturalTask association not found"
        end

        def delete_masters_crop_task_template!(crop_id:, template_id:)
          crop = find_crop_model!(crop_id.to_i)
          tpl = crop.crop_task_templates.find(template_id.to_i)
          tpl.destroy!
          :ok
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "AgriculturalTask association not found"
        end

        def find_crop_show_detail(crop_id)
          crop = crop_record_with_association_preloads!(crop_id)
          Domain::Crop::Dtos::CropDetailOutput.new(
            crop: Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
          )
        end

        def find_by_id(id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(find_crop_model!(id))
        end

        def resolve_crop_id_by_name(user_id:, crop_name:)
          name = crop_name.to_s.strip
          return nil if name.blank?

          record = ::Crop.reference.find_by(name: name)
          record ||= ::Crop.user_owned.where(user_id: user_id).find_by(name: name)
          record&.id
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

        def count_user_owned_non_reference_crops(user_id:)
          ::Crop.where(user_id: user_id, is_reference: false).count
        end

        def create_for_user(user, attrs)
          crop = ::Crop.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, crop.errors.full_messages.join(", ") unless crop.save

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        end

        def update_for_user(_user, id, attrs)
          crop = find_crop_model!(id)
          raise Domain::Shared::Exceptions::RecordInvalid, crop.errors.full_messages.join(", ") unless crop.update(attrs.to_h.symbolize_keys)

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop.reload)
        end

        def find_delete_usage(crop_id)
          crop = find_crop_model!(crop_id)
          Domain::Crop::Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: crop.cultivation_plan_crops.count,
            free_crop_plans_count: crop.free_crop_plans.count,
            pesticides_count: crop.pesticides.count
          )
        end

        def soft_delete_with_undo(user:, crop_id:, auto_hide_after: 5000, translator:)
          crop = find_crop_model!(crop_id)
          toast_message = translator.t("crops.undo.toast", name: crop.name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: crop.class.name,
            resource_id: crop.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        # CropStage methods
        def create_crop_stage(create_dto)
          crop_stage_attributes = attributes_from_crop_stage_dto(create_dto.payload)
          crop_stage_attributes[:crop_id] = create_dto.crop_id

          crop_stage = ::CropStage.new(crop_stage_attributes)
          unless crop_stage.save
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage)
        end

        def update_crop_stage(crop_stage_id, update_dto)
          crop_stage = ::CropStage.find(crop_stage_id)
          attrs = attributes_from_crop_stage_dto(update_dto.payload)

          unless crop_stage.update(attrs)
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def delete_crop_stage(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          unless crop_stage.destroy
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def list_by_crop_id(crop_id)
          crop_stages = ::CropStage.where(crop_id: crop_id).order(:order)
          crop_stages.map { |record| crop_stage_entity_from_record(record) }
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::TemperatureRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          temperature_requirement_entity_from_record(requirement)
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          requirement = ::TemperatureRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          temperature_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "TemperatureRequirement not found"
        end

        def delete_temperature_requirement(crop_stage_id)
          requirement = ::TemperatureRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "TemperatureRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # ThermalRequirement methods
        def create_thermal_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::ThermalRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          thermal_requirement_entity_from_record(requirement)
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          requirement = ::ThermalRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          thermal_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "ThermalRequirement not found"
        end

        def delete_thermal_requirement(crop_stage_id)
          requirement = ::ThermalRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "ThermalRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # SunshineRequirement methods
        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::SunshineRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          sunshine_requirement_entity_from_record(requirement)
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          requirement = ::SunshineRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          sunshine_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "SunshineRequirement not found"
        end

        def delete_sunshine_requirement(crop_stage_id)
          requirement = ::SunshineRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "SunshineRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # NutrientRequirement methods
        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::NutrientRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          nutrient_requirement_entity_from_record(requirement)
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          requirement = ::NutrientRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          nutrient_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "NutrientRequirement not found"
        end

        def delete_nutrient_requirement(crop_stage_id)
          requirement = ::NutrientRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "NutrientRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        private

        def raise_record_invalid_for_model!(record)
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            record.errors.full_messages.join(", "),
            errors: Domain::Shared::ValidationErrors.from_errors_like(record.errors)
          )
        end

        def agricultural_task_snapshot_from_record(record)
          return nil unless record

          Domain::Crop::Dtos::AgriculturalTaskSnapshot.new(
            id: record.id,
            name: record.name,
            description: record.description,
            is_reference: record.is_reference
          )
        end

        def masters_crop_task_template_dto_from_record(template, task_snapshot)
          Domain::Crop::Dtos::MastersCropTaskTemplate.new(
            id: template.id,
            crop_id: template.crop_id,
            agricultural_task_id: template.agricultural_task_id,
            name: template.name,
            description: template.description,
            time_per_sqm: template.time_per_sqm,
            weather_dependency: template.weather_dependency,
            required_tools: template.required_tools || [],
            skill_level: template.skill_level,
            agricultural_task: task_snapshot,
            created_at: template.created_at,
            updated_at: template.updated_at
          )
        end

        def masters_crop_task_template_api_row(template)
          at = template.agricultural_task
          {
            id: template.id,
            crop_id: template.crop_id,
            agricultural_task_id: template.agricultural_task_id,
            name: template.name,
            description: template.description,
            time_per_sqm: template.time_per_sqm,
            weather_dependency: template.weather_dependency,
            required_tools: template.required_tools || [],
            skill_level: template.skill_level,
            agricultural_task: at ? {
              id: at.id,
              name: at.name,
              description: at.description,
              is_reference: at.is_reference
            } : nil,
            created_at: template.created_at,
            updated_at: template.updated_at
          }
        end

        def index_relation_for_filter(filter)
          case filter.mode
          when :reference_or_owned
            ::Crop.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            ::Crop.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
          end
        end

        def user_owned_non_reference_scope(user)
          ::Crop.where(user_id: user.id, is_reference: false)
        end

        def find_crop_model!(id)
          crop = ::Crop.find(id)
          crop
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
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

        def crop_record_with_association_preloads!(id)
          ::Crop.includes(CROP_ASSOCIATION_PRELOAD_INCLUDES).find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

      end
    end
  end
end
