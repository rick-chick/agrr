# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestUpdateHtmlPresenter < Domain::Pest::Ports::PestUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pest_entity)
          @view.redirect_to(
            @view.pest_path(pest_entity.id),
            notice: I18n.t("pests.flash.updated")
          )
        end

        def on_failure(failure_dto)
          if failure_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.flash[:alert] = I18n.t("pests.flash.no_permission")
            @view.redirect_to @view.pests_path
            return
          end

          if failure_dto.is_a?(Domain::Pest::Dtos::PestReferenceFlagChangeDenied)
            @view.redirect_to @view.pest_path(failure_dto.pest_id), alert: failure_dto.message
            return
          end

          msg = failure_dto.respond_to?(:message) ? failure_dto.message : failure_dto.to_s

          @view.flash.now[:alert] = msg
          apply_pest_master_form_failure(failure_dto) if failure_dto.is_a?(Domain::Pest::Dtos::PestMasterFormFailure)
          @view.render_form(:edit, status: :unprocessable_entity)
        end

        private

        def apply_pest_master_form_failure(failure_dto)
          @view.instance_variable_set(:@pest, Forms::PestMasterForm.from_edit_payload(failure_dto.master_edit_payload))
          bundle = failure_dto.crop_selection_bundle
          return if bundle.nil?

          @view.instance_variable_set(:@selected_crop_ids, bundle.selected_crop_ids)
          @view.instance_variable_set(:@crop_cards, bundle.crop_cards)
        end
      end
    end
  end
end
