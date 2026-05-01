# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropListHtmlPresenter < Domain::Crop::Ports::CropListOutputPort
        def initialize(view:, crop_records_for_entities:)
          @view = view
          @crop_records_for_entities = crop_records_for_entities
        end

        def on_success(crops)
          @view.instance_variable_set(:@crops, @crop_records_for_entities.call(crops))
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
