# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # 参照 AgriculturalTask id → ユーザー所有 task id の解決（Adapter 注入）。
      class UserAgriculturalTaskMappingPort
        # @param reference_task_id [Integer, nil]
        # @return [Integer, nil]
        def user_task_id_for(reference_task_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
