# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # 公開プラン保存の永続化（Adapter が PlanSaveSession / TemplateCopyGateway を実装）。
      class PublicPlanSavePersistencePort
        # @param workspace [Dtos::PublicPlanSaveWorkspace]
        # @return [Dtos::PublicPlanSaveFromSessionOutput]
        def execute_save!(workspace:)
          raise NotImplementedError
        end
      end
    end
  end
end
