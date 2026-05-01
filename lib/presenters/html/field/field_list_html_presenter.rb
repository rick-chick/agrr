# frozen_string_literal: true

module Presenters
  module Html
    module Field
      class FieldListHtmlPresenter < Domain::Field::Ports::FieldListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farm_fields_list)
          @view.instance_variable_set(:@farm, farm_fields_list.farm)
          @view.instance_variable_set(:@fields, farm_fields_list.fields)
        end

        def on_failure(error_dto)
          @view.redirect_to @view.farms_path, alert: error_dto.message
        end
      end
    end
  end
end
