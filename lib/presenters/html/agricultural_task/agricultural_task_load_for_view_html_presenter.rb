# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskLoadForViewHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@agricultural_task, bundle.persisted_agricultural_task)
        end

        def on_failure(reason)
          alert = case reason
          when :no_permission
            I18n.t("agricultural_tasks.flash.no_permission")
          else
            I18n.t("agricultural_tasks.flash.not_found")
          end
          @view.redirect_to @view.agricultural_tasks_path, alert: alert
        end
      end
    end
  end
end
