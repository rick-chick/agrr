# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropToggleTaskTemplateHtmlPresenter < Domain::Crop::Ports::CropToggleTaskTemplateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(result)
          @view.instance_variable_set(:@available_agricultural_tasks, result.available_agricultural_tasks)
          @view.instance_variable_set(:@selected_task_ids, result.selected_task_ids)
          @view.instance_variable_set(:@task_schedule_blueprints, result.task_schedule_blueprints)

          return if @view.request.format.symbol == :turbo_stream

          crop = @view.instance_variable_get(:@crop)
          @view.redirect_to @view.crop_path(crop)
        end

        def on_failure(error)
          crop = @view.instance_variable_get(:@crop)
          path = crop ? @view.crop_path(crop) : @view.crops_path

          if error.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_to path, alert: I18n.t("crops.flash.no_permission")
            return
          end

          message = error.respond_to?(:message) ? error.message : error.to_s
          @view.redirect_to path, alert: message
        end
      end
    end
  end
end
