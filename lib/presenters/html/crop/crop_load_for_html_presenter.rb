# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropLoadForHtmlPresenter
        def initialize(view:, permission_message_key: nil)
          @view = view
          @permission_message_key = permission_message_key
        end

        def on_success(crop)
          @view.instance_variable_set(:@crop, crop)
        end

        def on_failure
          alert_key = @permission_message_key || "crops.flash.no_permission"
          @view.redirect_to @view.crops_path, alert: I18n.t(alert_key)
        end
      end
    end
  end
end
