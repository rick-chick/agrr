# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropDetailHtmlPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          @view.instance_variable_set(:@crop, crop_detail_dto.crop)
          @view.instance_variable_set(:@task_schedule_blueprints,
                                     crop_detail_dto.task_schedule_blueprints)
          @view.instance_variable_set(:@available_agricultural_tasks,
                                     crop_detail_dto.available_agricultural_tasks)
          @view.instance_variable_set(:@selected_task_ids,
                                     crop_detail_dto.selected_task_ids)
          @view.instance_variable_set(:@pests, crop_detail_dto.associated_pests)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("crops.flash.no_permission")
            @view.redirect_to @view.crops_path
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_to @view.crops_path, alert: msg
        end
      end
    end
  end
end
