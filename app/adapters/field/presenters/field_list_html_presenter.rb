# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldListHtmlPresenter < Domain::Field::Ports::FieldListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_fields_list)
          @view.instance_variable_set(:@farm, farm_fields_list.farm)
          @view.instance_variable_set(:@fields, farm_fields_list.fields)
          @view.instance_variable_set(:@turbo_stream_subscription, farm_fields_list.turbo_stream_subscription)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.farms_path,
                               alert: I18n.t("fields.flash.no_permission")
            return
          end

          @view.redirect_to @view.farms_path, alert: error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
        end
      end
    end
  end
end
