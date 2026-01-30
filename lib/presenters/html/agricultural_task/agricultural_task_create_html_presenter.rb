# frozen_string_literal: true

module Presenters
  module Html
    module AgriculturalTask
      class AgriculturalTaskCreateHtmlPresenter < Domain::AgriculturalTask::Ports::AgriculturalTaskCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(task)
          @view.redirect_to @view.agricultural_task_path(task), notice: I18n.t('agricultural_tasks.flash.created')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.render :new, status: :unprocessable_entity
        end
      end
    end
  end
end