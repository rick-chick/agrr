# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # CultivationPlanManageable の find（RecordNotFound をハッシュに正規化）
    module ManageablePrivatePlanLookup
      module_function

      # @return [Hash] { kind: :ok, plan: CultivationPlan } または { kind: :not_found }
      def call(scope:, plan_id:)
        { kind: :ok, plan: scope.find(plan_id) }
      rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound
        { kind: :not_found }
      end
    end
  end
end
