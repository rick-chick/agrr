# frozen_string_literal: true

module Presenters
  module Html
    module Field
      class FieldListHtmlPresenter < Domain::Field::Ports::FieldListOutputPort
        def initialize(view:, farm:)
          @view = view
          @farm = farm
        end

        def on_success(fields)
          gw = CompositionRoot.field_gateway
          @view.instance_variable_set(:@fields, fields.map { |f| gw.find_model(f.id) })
          @view.instance_variable_set(:@farm, @farm)
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@fields, [])
          @view.instance_variable_set(:@farm, @farm)
        end
      end
    end
  end
end
