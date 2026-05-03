# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropDetailHtmlPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          @view.instance_variable_set(:@crop, crop_detail_dto.persisted_crop)
          @view.instance_variable_set(:@task_schedule_blueprints, crop_detail_dto.task_schedule_blueprints)
          @view.instance_variable_set(:@available_agricultural_tasks, crop_detail_dto.available_agricultural_tasks)
          @view.instance_variable_set(:@selected_task_ids, crop_detail_dto.selected_task_ids)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("crops.flash.no_permission")
            @view.redirect_to @view.crops_path
            return
          end

          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.crops_path
        end
      end
    end
  end
end
