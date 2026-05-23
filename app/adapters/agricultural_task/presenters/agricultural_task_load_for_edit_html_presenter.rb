# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      class AgriculturalTaskLoadForEditHtmlPresenter
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(bundle)
          @view.instance_variable_set(:@agricultural_task,
            Forms::AgriculturalTaskMasterForm.from_snapshot(bundle.master_form_snapshot))
          assign_html_display(@view, bundle.html_display) if bundle.html_display
        end

        def on_failure(error_type)
          case error_type
          when :no_permission
            @view.render plain: "No permission"
          when :not_found
            @view.render plain: "Not found"
          else
            @view.render plain: "Unknown error"
          end
        end
      end
    end
  end
end
