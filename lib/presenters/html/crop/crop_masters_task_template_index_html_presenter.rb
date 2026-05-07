# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropMastersTaskTemplateIndexHtmlPresenter < Domain::Crop::Ports::CropMastersTaskTemplateIndexOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(rows)
          @view.instance_variable_set(:@task_template_rows, rows)
        end

        def on_failure(failure_dto)
          case failure_dto.reason
          when :crop_not_found
            @view.redirect_to @view.crops_path, alert: I18n.t("crops.flash.not_found")
          else
            if development_environment?
              raise ArgumentError,
                    "CropMastersTaskTemplateIndexHtmlPresenter: unknown failure reason #{failure_dto.reason.inspect}"
            end

            @view.redirect_to @view.crops_path, alert: failure_dto.message.presence || I18n.t("crops.flash.not_found")
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
