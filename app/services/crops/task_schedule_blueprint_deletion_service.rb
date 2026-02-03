# frozen_string_literal: true

module Crops
  # Service responsible for deleting a task schedule blueprint and its template
  # when no other blueprints reference the same agricultural_task_id.
  class TaskScheduleBlueprintDeletionService
    def initialize(crop:, blueprint:)
      @crop = crop
      @blueprint = blueprint
    end

    # Performs deletion inside a transaction and returns a hash with results:
    # { blueprint_deleted: bool, template_deleted: bool }
    def call
      blueprint_deleted = false
      template_deleted = false

      ActiveRecord::Base.transaction do
        blueprint_deleted = !!@blueprint.destroy!

        agricultural_task_id = @blueprint.agricultural_task_id
        if agricultural_task_id.present?
          has_remaining = @crop.crop_task_schedule_blueprints
                               .where(agricultural_task_id: agricultural_task_id)
                               .exists?

          unless has_remaining
            template = @crop.crop_task_templates.find_by(agricultural_task_id: agricultural_task_id)
            if template
              Rails.logger.info("🗑️ [TaskScheduleBlueprintDeletionService] Deleting template: template_id=#{template.id}, agricultural_task_id=#{agricultural_task_id}")
              template.destroy!
              template_deleted = true
            end
          end
        end
      end

      { blueprint_deleted: blueprint_deleted, template_deleted: template_deleted }
    end
  end
end

# frozen_string_literal: true

module Crops
  # Service responsible for deleting a task schedule blueprint and its template
  # when no other blueprints reference the same agricultural_task_id.
  #
  # Usage:
  #   service = Crops::TaskScheduleBlueprintDeletionService.new(crop: crop, blueprint: blueprint)
  #   result = service.call
  #   # => { blueprint_deleted: true/false, template_deleted: true/false }
  class TaskScheduleBlueprintDeletionService
    def initialize(crop:, blueprint:)
      @crop = crop
      @blueprint = blueprint
    end

    def call
      blueprint_deleted = false
      template_deleted = false

      ActiveRecord::Base.transaction do
        blueprint_deleted = !!@blueprint.destroy!

        agricultural_task_id = @blueprint.agricultural_task_id
        if agricultural_task_id.present?
          has_remaining = @crop.crop_task_schedule_blueprints.where(agricultural_task_id: agricultural_task_id).exists?
          unless has_remaining
            template = @crop.crop_task_templates.find_by(agricultural_task_id: agricultural_task_id)
            if template
              Rails.logger.info("🗑️ [TaskScheduleBlueprintDeletionService] Deleting template: template_id=#{template.id}, agricultural_task_id=#{agricultural_task_id}")
              template.destroy!
              template_deleted = true
            end
          end
        end
      end

      { blueprint_deleted: blueprint_deleted, template_deleted: template_deleted }
    end
  end
end

