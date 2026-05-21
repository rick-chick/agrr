# frozen_string_literal: true

module Adapters
  module ApiKeys
    module Presenters
      class UserApiKeyRotateHtmlPresenter
        def initialize(view:, regenerate:)
          @view = view
          @success_flash_key = regenerate ? "api_keys.flash.regenerate.success" : "api_keys.flash.generate.success"
          @failure_flash_key = regenerate ? "api_keys.flash.regenerate.failure" : "api_keys.flash.generate.failure"
        end

        def on_success(api_key:)
          @view.redirect_to(
            @view.api_keys_path,
            notice: I18n.t(@success_flash_key)
          )
        end

        def on_failure(message:)
          @view.redirect_to(
            @view.api_keys_path,
            alert: I18n.t(@failure_flash_key)
          )
        end
      end
    end
  end
end
