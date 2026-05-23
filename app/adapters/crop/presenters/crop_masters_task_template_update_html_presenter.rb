# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropMastersTaskTemplateUpdateHtmlPresenter < Domain::Crop::Ports::CropMastersTaskTemplateUpdateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(_row)
          crop = @view.instance_variable_get(:@crop)
          @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                            notice: I18n.t("crops.agricultural_tasks.flash.template_updated")
        end

        def on_failure(failure_dto)
          crop = @view.instance_variable_get(:@crop)
          case failure_dto.reason
          when :validation_failed
            msgs = Array(failure_dto.errors).compact
            @view.flash.now[:alert] = msgs.join(", ") if msgs.any?
            @view.render :edit, status: :unprocessable_entity
          when :association_not_found, :crop_not_found
            @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                              alert: I18n.t("crops.flash.not_found")
          else
            if development_environment?
              raise ArgumentError,
                    "CropMastersTaskTemplateUpdateHtmlPresenter: unknown failure reason #{failure_dto.reason.inspect}"
            end

            @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                              alert: failure_dto.message.presence || I18n.t("crops.flash.not_found")
          end
        end

        private

        def development_environment?
          defined?(Rails) && Rails.respond_to?(:env) && Rails.env.development?
        end
      end
    end
  end
end
