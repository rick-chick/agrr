# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeListHtmlPresenter < Domain::Fertilize::Ports::FertilizeListOutputPort
        def initialize(view:, fertilize_records_for_entities:)
          @view = view
          @fertilize_records_for_entities = fertilize_records_for_entities
        end

        def on_success(fertilizes)
          @view.instance_variable_set(:@fertilizes, @fertilize_records_for_entities.call(fertilizes))
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :index, status: :unprocessable_entity
        end
      end
    end
  end
end
