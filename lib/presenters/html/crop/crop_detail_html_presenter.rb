# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropDetailHtmlPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          crop_entity = crop_detail_dto.crop
          crop_model = Domain::Crop::Gateways::CropGateway.default.find_model(crop_entity.id)
          task_schedule_blueprints = crop_model.crop_task_schedule_blueprints
                                        .includes(:agricultural_task)
                                        .ordered
          selected_task_ids = crop_model.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
          available_tasks = available_agricultural_tasks_for_crop(crop_model)

          @view.instance_variable_set(:@crop, crop_model)
          @view.instance_variable_set(:@task_schedule_blueprints, task_schedule_blueprints)
          @view.instance_variable_set(:@available_agricultural_tasks, available_tasks)
          @view.instance_variable_set(:@selected_task_ids, selected_task_ids)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.crops_path
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
      end
    end
  end
end
