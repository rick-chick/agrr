# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      module MastersCropTaskTemplateCreatePolicy
        module_function

        def duplicate?(existing_link:)
          !existing_link.nil?
        end

        # @param input_dto [Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput]
        # @param task_entity [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity]
        # @return [Domain::Crop::Dtos::CropTaskTemplatePersistAttributes]
        def build_persist_attributes(input_dto, task_entity)
          Domain::Crop::Dtos::CropTaskTemplatePersistAttributes.new(
            name: input_dto.name.nil? ? task_entity.name : input_dto.name,
            description: input_dto.description.nil? ? task_entity.description : input_dto.description,
            time_per_sqm: input_dto.time_per_sqm.nil? ? task_entity.time_per_sqm : input_dto.time_per_sqm,
            weather_dependency: input_dto.weather_dependency.nil? ? task_entity.weather_dependency : input_dto.weather_dependency,
            required_tools: input_dto.required_tools.nil? ? task_entity.required_tools : input_dto.required_tools,
            skill_level: input_dto.skill_level.nil? ? task_entity.skill_level : input_dto.skill_level
          )
        end

        # @param template_entity [Domain::Crop::Entities::CropTaskTemplateEntity]
        # @param task_entity [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity]
        # @return [Domain::Crop::Dtos::MastersCropTaskTemplate]
        def to_masters_dto(template_entity, task_entity)
          task_snapshot = Domain::Crop::Dtos::AgriculturalTaskSnapshot.new(
            id: task_entity.id,
            name: task_entity.name,
            description: task_entity.description,
            is_reference: task_entity.is_reference
          )
          Domain::Crop::Dtos::MastersCropTaskTemplate.new(
            id: template_entity.id,
            crop_id: template_entity.crop_id,
            agricultural_task_id: template_entity.agricultural_task_id,
            name: template_entity.name,
            description: template_entity.description,
            time_per_sqm: template_entity.time_per_sqm,
            weather_dependency: template_entity.weather_dependency,
            required_tools: template_entity.required_tools,
            skill_level: template_entity.skill_level,
            agricultural_task: task_snapshot,
            created_at: template_entity.created_at,
            updated_at: template_entity.updated_at
          )
        end
      end
    end
  end
end
