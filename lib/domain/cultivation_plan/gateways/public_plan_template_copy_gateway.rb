# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開計画テンプレートからユーザー私有計画へのコピー（年度コピー PlanCopyGateway とは別）。
      class PublicPlanTemplateCopyGateway
        # @param ctx [Object] adapter 内部の PlanSaveContext（Task E で DTO 化）
        # @return [Object] 新規 CultivationPlan AR（adapter 境界）
        def copy_cultivation_plan(ctx:, farm:, crops:)
          raise NotImplementedError
        end

        def establish_master_data_relationships(ctx:, farm:, crops:, fields:, pests:, agricultural_tasks:, fertilizes:, pesticides:, interaction_rules:)
          raise NotImplementedError
        end

        # @return [Hash] field_cultivation_map
        def copy_plan_relations(ctx:, new_plan:)
          raise NotImplementedError
        end

        def copy_task_schedules(ctx:, new_plan:, field_cultivation_map:)
          raise NotImplementedError
        end
      end
    end
  end
end
