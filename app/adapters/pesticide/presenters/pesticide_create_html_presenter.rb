# frozen_string_literal: true

module Adapters
  module Pesticide
    module Presenters
      class PesticideCreateHtmlPresenter < Domain::Pesticide::Ports::PesticideCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(pesticide_entity)
          @view.redirect_to @view.pesticide_path(pesticide_entity.id), notice: I18n.t("pesticides.flash.created")
        end

        def on_failure(error_dto)
          if error_dto.is_a?(Domain::Shared::Policies::PolicyPermissionDenied)
            @view.redirect_back fallback_location: @view.pesticides_path,
                               alert: I18n.t("pesticides.flash.no_permission")
            return
          end

          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          if msg == I18n.t("pesticides.flash.reference_only_admin")
            @view.redirect_to @view.pesticides_path, alert: msg
            return
          end

          @view.flash.now[:alert] = msg
          if error_dto.is_a?(Domain::Pesticide::Dtos::PesticideHtmlMasterFormFailure)
            b = error_dto.bundle
            @view.instance_variable_set(:@pesticide, Forms::PesticideMasterForm.from_snapshot(b.pesticide_master_form_snapshot))
            @view.instance_variable_set(:@crops, b.crop_pick_rows)
            @view.instance_variable_set(:@pests, b.pest_pick_rows)
          end
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end
