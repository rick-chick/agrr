# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeCreateHtmlPresenter < Domain::Fertilize::Ports::FertilizeCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_entity)
          @view.redirect_to(
            @view.fertilize_path(fertilize_entity.id),
            notice: I18n.t('fertilizes.flash.created')
          )
        end

        def on_failure(error_dto)
          @view.instance_variable_set(:@fertilize, ::Fertilize.new(@view.params[:fertilize].to_h.symbolize_keys))
          @view.instance_variable_get(:@fertilize).valid?
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :new, status: :unprocessable_entity
        end
      end
    end
  end
end