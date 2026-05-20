# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Action Cable の `broadcast_to` ストリーム解決用の最小識別子（永続計画 id のみ）。
      # アダプタ内で {::CultivationPlan} を再読込する。
      class CultivationPlanCableTarget
        attr_reader :cultivation_plan_id

        def initialize(cultivation_plan_id:)
          @cultivation_plan_id = cultivation_plan_id
          freeze
        end
      end
    end
  end
end
