# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Policies
      # HTML 更新時の CropTaskTemplate 同期（作物スコープとの突合・差分は Policy、I/O は Gateway）。
      module CropTaskTemplateSyncPolicy
        module_function

        # 農業タスクに region があるときのみ作物を region で絞る（無ければ Gateway は region 条件を付けない）。
        def crop_associate_region_filter(region:)
          return nil if Domain::Shared.blank?(region)

          region
        end

        def normalize_selected_crop_ids(selected_crop_ids)
          Array(selected_crop_ids).map(&:to_i).uniq
        end

        # @param scope_crop_ids [Array<Integer>] Gateway が返した関連付け可能な作物 ID
        def allowed_crop_ids(scope_crop_ids:, selected_crop_ids:)
          scope_set = scope_crop_ids.to_set
          normalize_selected_crop_ids(selected_crop_ids).select { |id| scope_set.include?(id) }
        end

        def crops_to_add(allowed_crop_ids:, current_template_crop_ids:)
          allowed_crop_ids - current_template_crop_ids
        end

        def crops_to_remove(allowed_crop_ids:, current_template_crop_ids:)
          current_template_crop_ids - allowed_crop_ids
        end

        # @param crop_found [Boolean] Gateway が作物 ID の存在を返したか
        # @param template_exists [Boolean] Gateway が既存テンプレートの有無を返したか
        def skip_template_create?(crop_found:, template_exists:)
          !crop_found || template_exists
        end

        def skip_template_remove?(crop_found:, template_exists:)
          !crop_found || !template_exists
        end

        def template_attributes_from_task_entity(task_entity)
          {
            name: task_entity.name,
            description: task_entity.description,
            time_per_sqm: task_entity.time_per_sqm,
            weather_dependency: task_entity.weather_dependency,
            required_tools: task_entity.required_tools,
            skill_level: task_entity.skill_level
          }
        end
      end
    end
  end
end
