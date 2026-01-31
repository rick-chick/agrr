# frozen_string_literal: true

module Presenters
  module Html
    module Crop
      class CropDetailHtmlPresenter < Domain::Crop::Ports::CropDetailOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crop_detail_dto)
          crop_model = crop_detail_dto.crop.to_model
          @view.instance_variable_set(:@crop, crop_model)

          @view.instance_variable_set(:@task_schedule_blueprints,
            crop_model.crop_task_schedule_blueprints
                      .includes(:agricultural_task)
                      .ordered)

          available_tasks = available_agricultural_tasks_for_crop(crop_model)
          @view.instance_variable_set(:@available_agricultural_tasks, available_tasks)

          selected_ids = crop_model.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
          @view.instance_variable_set(:@selected_task_ids, selected_ids)
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.redirect_to @view.crops_path
        end

        private

        def available_agricultural_tasks_for_crop(crop)
          # ユーザ作物であればそのユーザの作業のみ（モデルは ::AgriculturalTask で明示）
          if !crop.is_reference && crop.user_id.present?
            tasks = ::AgriculturalTask.user_owned.where(user_id: crop.user_id)
            # 地域が設定されていればその地域も条件に追加
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          # 参照作物であれば参照作業のみ
          if crop.is_reference
            tasks = ::AgriculturalTask.reference
            # 地域が設定されていればその地域も条件に追加
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          # どちらでもない場合は空のコレクション
          ::AgriculturalTask.none
        end
      end
    end
  end
end