# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropListHtmlPresenter < Domain::Crop::Ports::CropListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.instance_variable_set(:@crops, crops.map(&:to_model))
          # index テンプレートをレンダリング（暗黙的に）
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@crops, [])
        end
      end
    end
  end
end