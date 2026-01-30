# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeDestroyHtmlPresenter < Domain::Fertilize::Ports::FertilizeDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata['resource_label']
            @view.redirect_back fallback_location: @view.fertilizes_path,
                               notice: I18n.t('deletion_undo.redirect_notice', resource: resource_label)
          else
            # undo トークンがない場合は通常のリダイレクト
            @view.redirect_to @view.fertilizes_path, notice: I18n.t('fertilizes.flash.destroyed')
          end
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.redirect_back(
            fallback_location: @view.fertilizes_path,
            alert: msg
          )
        end
      end
    end
  end
end