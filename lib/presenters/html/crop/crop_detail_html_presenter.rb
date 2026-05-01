# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropDetailHtmlPresenter < Domain::Crop::Ports::CropDetailOutputPort
        # crop_show_view_data_for: CropDetailOutputDto -> Hash with :crop, :task_schedule_blueprints, :available_agricultural_tasks, :selected_task_ids
        def initialize(view:, crop_show_view_data_for:)
          @view = view
          @crop_show_view_data_for = crop_show_view_data_for
        end

        def on_success(crop_detail_dto)
          data = @crop_show_view_data_for.call(crop_detail_dto)
          @view.instance_variable_set(:@crop, data[:crop])
          @view.instance_variable_set(:@task_schedule_blueprints, data[:task_schedule_blueprints])
          @view.instance_variable_set(:@available_agricultural_tasks, data[:available_agricultural_tasks])
          @view.instance_variable_set(:@selected_task_ids, data[:selected_task_ids])
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.crops_path
        end
      end
    end
  end
end
