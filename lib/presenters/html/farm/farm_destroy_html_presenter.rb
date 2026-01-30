# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmDestroyHtmlPresenter < Domain::Farm::Ports::FarmDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata['resource_label']
            @view.redirect_back fallback_location: @view.farms_path,
                               notice: I18n.t('deletion_undo.redirect_notice', resource: resource_label)
          else
            # undo トークンがない場合は通常のリダイレクト
            @view.redirect_to @view.farms_path, notice: I18n.t('farms.flash.destroyed')
          end
        end

        def on_failure(error_dto)
          @view.redirect_back fallback_location: @view.farms_path, alert: error_dto.message
        end
      end
    end
  end
end