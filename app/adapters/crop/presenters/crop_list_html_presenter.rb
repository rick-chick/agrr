# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropListHtmlPresenter < Domain::Crop::Ports::CropListOutputPort
        include Adapters::Shared::Presenters::HtmlDisplaySupport

        def initialize(view:)
          @view = view
        end

        def on_success(rows)
          assign_list_row_view_models(@view, :@crops, rows)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.instance_variable_set(:@crops, [])
        end
      end
    end
  end
end
