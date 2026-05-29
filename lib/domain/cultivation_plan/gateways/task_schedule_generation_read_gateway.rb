# frozen_string_literal: true



module Domain

  module CultivationPlan

    module Gateways

      # Task schedule 生成用の narrow read（1 テーブル / 1 行種別ごと）。

      class TaskScheduleGenerationReadGateway

        # @return [Dtos::TaskScheduleGenerationReadSnapshots::PlanRowSnapshot]

        def find_plan_row(plan_id:)

          raise NotImplementedError, "Subclasses must implement find_plan_row"

        end



        # @return [Array<Dtos::TaskScheduleGenerationReadSnapshots::FieldCultivationRowSnapshot>]

        def list_field_cultivation_rows(plan_id:)

          raise NotImplementedError, "Subclasses must implement list_field_cultivation_rows"

        end



        # @return [Dtos::TaskScheduleGenerationReadSnapshots::CropRowSnapshot]

        def find_crop_row(crop_id:)

          raise NotImplementedError, "Subclasses must implement find_crop_row"

        end



        # @return [Array<Dtos::TaskScheduleGenerationReadSnapshots::CropTaskTemplateRowSnapshot>]

        def list_crop_task_template_rows(crop_id:)

          raise NotImplementedError, "Subclasses must implement list_crop_task_template_rows"

        end



        # @return [Array<Dtos::TaskScheduleGenerationReadSnapshots::BlueprintRowSnapshot>]

        def list_crop_task_schedule_blueprint_rows(crop_id:)

          raise NotImplementedError, "Subclasses must implement list_crop_task_schedule_blueprint_rows"

        end



        # CropAgrrRequirementBuilderPort 向け（adapter は stages 付き Crop のみ読む）

        # @return [Object] build_from に渡せる crop source

        def find_crop_agrr_requirement_source(crop_id:)

          raise NotImplementedError, "Subclasses must implement find_crop_agrr_requirement_source"

        end

      end

    end

  end

end


