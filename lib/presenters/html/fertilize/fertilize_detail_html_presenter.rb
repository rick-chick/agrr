# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeDetailHtmlPresenter < Domain::Fertilize::Ports::FertilizeDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_detail_dto)
          fertilize_model = fertilize_detail_dto.fertilize.to_model
          @view.instance_variable_set(:@fertilize, fertilize_model)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :show, status: :unprocessable_entity
        end
      end
    end
  end
end