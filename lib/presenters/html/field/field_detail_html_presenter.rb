# frozen_string_literal: true

module Presenters
  module Html
    module Field
      class FieldDetailHtmlPresenter < Domain::Field::Ports::FieldDetailOutputPort
        def initialize(view:, farm:, field_record_for_detail_dto:)
          @view = view
          @farm = farm
          @field_record_for_detail_dto = field_record_for_detail_dto
        end

        def on_success(detail_output_dto)
          @view.instance_variable_set(
            :@field,
            @field_record_for_detail_dto.call(detail_output_dto)
          )
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
