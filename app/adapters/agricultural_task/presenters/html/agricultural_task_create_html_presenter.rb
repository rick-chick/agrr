# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Presenters
      module Html
        class AgriculturalTaskCreateHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskCreateOutputPort
          def initialize(view:)
            @view = view
          end

          def on_success(task)
            @view.redirect_to @view.agricultural_task_path(task), notice: I18n.t("agricultural_tasks.flash.created")
          end

          def on_failure(error_dto)
            msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
            if msg == I18n.t("agricultural_tasks.flash.reference_only_admin")
              @view.redirect_to @view.agricultural_tasks_path, alert: msg
              return
            end

            @view.flash.now[:alert] = msg
            @view.after_agricultural_task_create_failure
            @view.render :new, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
