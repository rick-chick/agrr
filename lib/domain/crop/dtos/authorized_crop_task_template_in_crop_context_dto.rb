# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class AuthorizedCropTaskTemplateInCropContextDto
        attr_reader :crop_entity, :crop_task_template_dto

        def initialize(crop_entity:, crop_task_template_dto:)
          @crop_entity = crop_entity
          @crop_task_template_dto = crop_task_template_dto
        end
      end
    end
  end
end
