# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      module Html
        class FertilizeCreateHtmlPresenter < Domain::Fertilize::Ports::FertilizeCreateOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(fertilize_entity)
            @view.redirect_to(
              @view.fertilize_path(fertilize_entity.id),
              notice: I18n.t("fertilizes.flash.created")
            )
          end

          def on_failure(failure_dto)
            if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.redirect_back fallback_location: @view.fertilizes_path,
                                 alert: I18n.t("fertilizes.flash.no_permission")
              return
            end

            msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
            if msg == I18n.t("fertilizes.flash.reference_only_admin")
              @view.redirect_to @view.fertilizes_path, alert: msg
              return
            end

            @view.instance_variable_set(:@fertilize, failure_dto.master_form)
            @view.flash.now[:alert] = msg
            @view.render :new, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
