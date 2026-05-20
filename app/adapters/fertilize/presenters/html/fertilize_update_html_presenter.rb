# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      module Html
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
            if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
              @view.redirect_back fallback_location: @view.fertilizes_path,
                                 alert: I18n.t("fertilizes.flash.no_permission")
              return
            end

            msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s
            snapshot = failure_dto.respond_to?(:master_form_snapshot) ? failure_dto.master_form_snapshot : nil

            if snapshot.nil?
              @view.flash.now[:alert] = msg
              @view.redirect_to @view.fertilizes_path
              return
            end

            if msg == I18n.t("fertilizes.flash.reference_flag_admin_only")
              @view.redirect_to @view.fertilize_path(snapshot.id), alert: msg
              return
            end

            @view.instance_variable_set(:@fertilize, snapshot)
            @view.flash.now[:alert] = msg
            @view.render :edit, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
