# frozen_string_literal: true

module Adapters
  module Crop
    # 同一 agricultural_task_id を参照する他ブループリントが無くなったら、blueprint と crop_task_template をトランザクションで削除する。
    class TaskScheduleBlueprintDeletion
      def initialize(crop:, blueprint:)
        @crop = crop
        @blueprint = blueprint
      end

      # @return [Hash] { blueprint_deleted: bool, template_deleted: bool }
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
                Rails.logger.info("🗑️ [TaskScheduleBlueprintDeletion] Deleting template: template_id=#{template.id}, agricultural_task_id=#{agricultural_task_id}")
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
end
