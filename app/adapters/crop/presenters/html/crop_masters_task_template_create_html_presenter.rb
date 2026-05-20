# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      module Html
        class CropMastersTaskTemplateCreateHtmlPresenter < Domain::Crop::Ports::CropMastersTaskTemplateCreateOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(_template_dto)
            crop = @view.instance_variable_get(:@crop)
            @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                              notice: I18n.t("crops.agricultural_tasks.flash.template_created")
          end

          def on_failure(failure_dto)
            crop = @view.instance_variable_get(:@crop)
            case failure_dto.reason
            when :missing_agricultural_task_id
              @view.redirect_to @view.new_agricultural_task_path,
                                notice: I18n.t("crops.agricultural_tasks.flash.redirect_to_create")
            when :agricultural_task_not_found
              @view.redirect_to @view.new_agricultural_task_path,
                                notice: I18n.t("crops.agricultural_tasks.flash.redirect_to_create")
            when :forbidden
              @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                                alert: I18n.t("crops.agricultural_tasks.flash.no_permission")
            when :duplicate
              @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                                alert: I18n.t("crops.agricultural_tasks.flash.template_already_exists")
            when :validation_failed
              msgs = Array(failure_dto.errors).compact
              @view.redirect_to @view.crop_agricultural_tasks_path(crop),
                                alert: msgs.any? ? msgs.join(", ") : I18n.t("crops.flash.not_found")
            when :crop_not_found
              @view.redirect_to @view.crops_path, alert: I18n.t("crops.flash.not_found")
            else
              if development_environment?
                raise ArgumentError,
                      "CropMastersTaskTemplateCreateHtmlPresenter: unknown failure reason #{failure_dto.reason.inspect}"
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
end
