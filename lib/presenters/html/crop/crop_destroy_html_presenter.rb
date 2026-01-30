# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropDestroyHtmlPresenter < Domain::Crop::Ports::CropDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          if event&.undo_token.present?
            resource_label = event.metadata['resource_label']
            @view.redirect_back fallback_location: @view.crops_path,
                               notice: I18n.t('deletion_undo.redirect_notice', resource: resource_label)
          else
            # undo トークンがない場合は通常のリダイレクト
            @view.redirect_to @view.crops_path, notice: I18n.t('crops.flash.destroyed')
          end
        end

        def on_failure(error_dto)
          @view.redirect_back fallback_location: @view.crops_path, alert: error_dto.message
        end
      end
    end
  end
end