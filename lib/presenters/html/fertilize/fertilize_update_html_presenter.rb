# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeUpdateHtmlPresenter < Domain::Fertilize::Ports::FertilizeUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilize_entity)
          @view.redirect_to(
            @view.fertilize_path(fertilize_entity.id),
            notice: I18n.t('fertilizes.flash.updated')
          )
        end

        def on_failure(error_dto)
          @fertilize = @view.instance_variable_get(:@fertilize) || ::Fertilize.find(@view.params[:id])
          @fertilize.assign_attributes(@view.params[:fertilize].to_h.symbolize_keys)
          @fertilize.valid?
          @view.instance_variable_set(:@fertilize, @fertilize)
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end