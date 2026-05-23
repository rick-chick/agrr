# frozen_string_literal: true

module Adapters
  module Field
    module Presenters
      class FieldDetailHtmlPresenter < Domain::Field::Ports::FieldDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(field_with_farm)
          @view.instance_variable_set(:@farm, field_with_farm.farm)
          @view.instance_variable_set(:@field, field_with_farm.field)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          farm_id = error_dto.is_a?(Domain::Field::Dtos::FieldDetailFailure) ? error_dto.farm_id : nil
          if farm_id.present?
            @view.redirect_to @view.farm_fields_path(farm_id), alert: msg
          else
            @view.redirect_to @view.farms_path, alert: msg
          end
        end
      end
    end
  end
end
