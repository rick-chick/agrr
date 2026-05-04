# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropRegenerateTaskScheduleBlueprintsHtmlPresenter < Domain::Crop::Ports::CropRegenerateTaskScheduleBlueprintsOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success
          @view.redirect_to @view.crop_path(@view.instance_variable_get(:@crop)), notice: I18n.t("crops.flash.task_schedule_blueprints_generated")
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
