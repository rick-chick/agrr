# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      class CropTaskScheduleBlueprintDestroyPresenter < Domain::Crop::Ports::CropTaskScheduleBlueprintDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_forbidden
          @view.render json: { error: I18n.t("crops.flash.no_permission") }, status: :forbidden
        end

        def on_not_found(blueprint_id:)
          @view.respond_to do |format|
            format.turbo_stream do
              @view.render turbo_stream: @view.turbo_stream.remove("blueprint-card-#{blueprint_id}")
            end
            format.json do
              @view.render json: { error: I18n.t("crops.flash.blueprint_not_found") }, status: :not_found
            end
            format.html { @view.head :not_found }
          end
        end

        def on_reload_failed(blueprint_id:)
          @view.respond_to do |format|
            format.turbo_stream do
              @view.render turbo_stream: @view.turbo_stream.replace(
                "blueprint-card-#{blueprint_id}",
                partial: "crops/task_schedule_blueprints/error",
                locals: { error: I18n.t("crops.flash.blueprint_delete_failed") }
              )
            end
            format.json do
              @view.render json: { error: I18n.t("crops.flash.blueprint_delete_failed") }, status: :internal_server_error
            end
          end
        end

        def on_success(blueprint_id:, crop:, available_agricultural_tasks:, selected_task_ids:)
          @view.instance_variable_set(:@blueprint_id, blueprint_id)
          @view.instance_variable_set(:@crop, crop)
          @view.instance_variable_set(:@available_agricultural_tasks, available_agricultural_tasks)
          @view.instance_variable_set(:@selected_task_ids, selected_task_ids)

          @view.respond_to do |format|
            format.html { @view.head :no_content }
            format.turbo_stream
            format.json { @view.render json: { message: I18n.t("crops.flash.blueprint_deleted") } }
          end
        end
      end
    end
  end
end
