# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Entities
      class CropTaskTemplateLinkEntity
        attr_reader :id, :agricultural_task_id, :crop_id

        def initialize(id:, agricultural_task_id:, crop_id:)
          @id = id
          @agricultural_task_id = agricultural_task_id
          @crop_id = crop_id
        end
      end
    end
  end
end
