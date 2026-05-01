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
            notice: I18n.t("fertilizes.flash.updated")
          )
        end

        def on_failure(failure_dto)
          @fertilize = failure_dto.reload_bundle&.persisted_fertilize || @view.instance_variable_get(:@fertilize)
          @fertilize.assign_attributes(@view.params[:fertilize].to_h.symbolize_keys)
          @fertilize.valid?
          @view.instance_variable_set(:@fertilize, @fertilize)
          @view.flash.now[:alert] = failure_dto.message
          @view.render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
