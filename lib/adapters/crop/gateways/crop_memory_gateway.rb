# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropMemoryGateway < Domain::Crop::Gateways::CropGateway
        def list(scope = nil)
          query = scope || ::Crop.all
          query.map { |record| Domain::Crop::Entities::CropEntity.from_model(record) }
        end

        def find_by_id(crop_id)
          crop = ::Crop.find(crop_id)
          Domain::Crop::Entities::CropEntity.from_model(crop)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Crop not found'
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
          raise StandardError, crop.errors.full_messages.join(', ') unless crop.save

          Domain::Crop::Entities::CropEntity.from_model(crop)
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
          raise StandardError, crop.errors.full_messages.join(', ') if crop.errors.any?

          Domain::Crop::Entities::CropEntity.from_model(crop.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Crop not found'
        end

        # CropStage methods
        def create_crop_stage(create_dto)
          crop_stage_attributes = attributes_from_crop_stage_dto(create_dto.payload)
          crop_stage_attributes[:crop_id] = create_dto.crop_id

          crop_stage = ::CropStage.new(crop_stage_attributes)
          unless crop_stage.save
            raise StandardError, crop_stage.errors.full_messages.join(', ')
          end
          crop_stage_entity_from_record(crop_stage)
        end

        def update_crop_stage(crop_stage_id, update_dto)
          crop_stage = ::CropStage.find(crop_stage_id)
          attrs = attributes_from_crop_stage_dto(update_dto.payload)

          unless crop_stage.update(attrs)
            raise StandardError, crop_stage.errors.full_messages.join(', ')
          end
          crop_stage_entity_from_record(crop_stage.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'CropStage not found'
        end

        def delete_crop_stage(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          unless crop_stage.destroy
            raise StandardError, crop_stage.errors.full_messages.join(', ')
          end
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'CropStage not found'
        end

        def list_crop_stages_by_crop_id(crop_id)
          crop_stages = ::CropStage.where(crop_id: crop_id).order(:order)
          crop_stages.map { |record| crop_stage_entity_from_record(record) }
        end

        def find_crop_stage_by_id(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          crop_stage_entity_from_record(crop_stage)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'CropStage not found'
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
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          temperature_requirement_entity_from_record(requirement)
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          requirement = ::TemperatureRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          temperature_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'TemperatureRequirement not found'
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
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          thermal_requirement_entity_from_record(requirement)
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          requirement = ::ThermalRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          thermal_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'ThermalRequirement not found'
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
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          sunshine_requirement_entity_from_record(requirement)
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          requirement = ::SunshineRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          sunshine_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'SunshineRequirement not found'
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
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          nutrient_requirement_entity_from_record(requirement)
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          requirement = ::NutrientRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise StandardError, requirement.errors.full_messages.join(', ')
          end
          nutrient_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'NutrientRequirement not found'
        end

        private

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

      end
    end
  end
end


