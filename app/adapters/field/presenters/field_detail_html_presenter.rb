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
          farm_id = @view.params[:farm_id]
          if farm_id.present?
            @view.redirect_to @view.farm_fields_path(farm_id), alert: error_dto.message
          else
            @view.redirect_to @view.farms_path, alert: error_dto.message
          end
        end
      end
    end
  end
end
