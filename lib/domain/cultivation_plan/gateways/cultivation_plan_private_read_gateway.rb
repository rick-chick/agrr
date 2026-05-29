# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 私有計画の読み取り専用永続化（index / count のみ。snapshot 組立は各 *ReadGateway + domain mapper）。
      class CultivationPlanPrivateReadGateway
        # @return [Array<Domain::CultivationPlan::Mappers::Dtos::PlanRowSnapshot>]
        def list_private_plan_index_plan_snapshots(user_id:)
          raise NotImplementedError
        end

        # @param plan_ids [Array<Integer>]
        # @return [Hash{Integer => Integer}] plan_id => crops_count
        def count_cultivation_plan_crops_by_plan_ids(plan_ids:)
          raise NotImplementedError
        end

        # @param plan_ids [Array<Integer>]
        # @return [Hash{Integer => Integer}] plan_id => fields_count
        def count_cultivation_plan_fields_by_plan_ids(plan_ids:)
          raise NotImplementedError
        end
      end
    end
  end
end
