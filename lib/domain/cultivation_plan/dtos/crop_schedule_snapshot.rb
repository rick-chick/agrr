# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CropScheduleSnapshot
        attr_reader :id, :name, :crop_task_templates, :crop_task_schedule_blueprints, :agrr_requirement

        def initialize(id:, name:, crop_task_templates:, crop_task_schedule_blueprints:, agrr_requirement:)
          @id = id
          @name = name
          @crop_task_templates = crop_task_templates
          @crop_task_schedule_blueprints = crop_task_schedule_blueprints
          @agrr_requirement = agrr_requirement
        end

        def to_agrr_requirement
          @agrr_requirement
        end
      end
    end
  end
end
