# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmListHtmlPresenter < Domain::Farm::Ports::FarmListRowsBundleOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rows_bundle_dto)
          @view.instance_variable_set(:@farms, rows_bundle_dto.farm_rows)
          @view.instance_variable_set(:@reference_farms, rows_bundle_dto.reference_farm_rows)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.farms_path,
                               alert: I18n.t("farms.flash.no_permission")
            return
          end

          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.instance_variable_set(:@farms, [])
          @view.instance_variable_set(:@reference_farms, [])
        end
      end
    end
  end
end
