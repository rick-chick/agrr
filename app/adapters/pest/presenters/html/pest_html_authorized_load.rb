# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      module Html
        class PestHtmlAuthorizedLoad < Domain::Pest::Ports::PestAuthorizedLoad
          def initialize(view:)
            @view = view
          end

          def on_success(bundle)
            @view.instance_variable_set(:@pest, bundle.pest_master_edit_payload)
            @view.prepare_crop_selection_for(bundle.pest_master_edit_payload)
            @view.render_form(:edit)
          end

          def on_failure(failure_type)
            case failure_type
            when :no_permission
              @view.redirect_to @view.pests_path, alert: I18n.t("pests.flash.no_permission")
            when :not_found
              @view.redirect_to @view.pests_path, alert: I18n.t("pests.flash.not_found")
            end
          end
        end
      end
    end
  end
end
