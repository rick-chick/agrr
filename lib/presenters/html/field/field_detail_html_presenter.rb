# frozen_string_literal: true

module Presenters
  module Html
    module Field
      class FieldDetailHtmlPresenter < Domain::Field::Ports::FieldDetailOutputPort
        def initialize(view:, farm:)
          @view = view
          @farm = farm
        end

        def on_success(detail_output_dto)
          @view.instance_variable_set(:@field, detail_output_dto.field.to_model)
          @view.instance_variable_set(:@farm, @farm)
          # show テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.redirect_to @view.farm_fields_path(@farm.id), alert: error_dto.message
        end
      end
    end
  end
end