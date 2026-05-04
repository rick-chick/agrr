# frozen_string_literal: true

module Presenters
  module Html
    module Fertilize
      class FertilizeListHtmlPresenter < Domain::Fertilize::Ports::FertilizeListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(fertilizes)
          @view.instance_variable_set(:@fertilizes, fertilizes)
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.fertilizes_path,
                               alert: I18n.t("fertilizes.flash.no_permission")
            return
          end

          @view.instance_variable_set(:@fertilizes, [])
          @view.flash.now[:alert] = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @view.render :index, status: :unprocessable_entity
        end
      end
    end
  end
end
