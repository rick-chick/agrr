# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeDetailHtmlPresenter < Domain::Fertilize::Ports::FertilizeDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_detail_dto)
          @view.instance_variable_set(:@fertilize, fertilize_detail_dto.fertilize)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_to @view.fertilizes_path, alert: msg
        end
      end
    end
  end
end
