# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropNestedCropTaskTemplatesNewHtmlPresenter < Domain::Crop::Ports::CropNestedCropTaskTemplatesNewOutputPort
        PicklistRow = Struct.new(:id, :name)

        def initialize(view:)
          @view = view
        end

        def on_success(picklist_rows)
          rows =
            picklist_rows.map do |r|
              PicklistRow.new(r[:id], r[:name])
            end
          @view.instance_variable_set(:@selectable_agricultural_tasks, rows)
        end

        def on_failure(failure_dto)
          case failure_dto.reason
          when :crop_not_found
            @view.redirect_to @view.crops_path, alert: I18n.t("crops.flash.not_found")
          else
            if development_environment?
              raise ArgumentError,
                    "CropNestedCropTaskTemplatesNewHtmlPresenter: unknown failure reason #{failure_dto.reason.inspect}"
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
