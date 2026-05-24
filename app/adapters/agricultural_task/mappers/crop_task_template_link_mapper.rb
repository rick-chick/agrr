# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Mappers
      module CropTaskTemplateLinkMapper
        module_function

        def link_entity_from_record(record)
          Domain::AgriculturalTask::Entities::CropTaskTemplateLinkEntity.new(
            id: record.id,
            agricultural_task_id: record.agricultural_task_id,
            crop_id: record.crop_id
          )
        end
      end
    end
  end
end
