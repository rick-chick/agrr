# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # ORM 非依存の栽培計画読み取り可否（private 本人 / public）。
      module PlanReadAuthorization
        module_function

        # @param plan_type_private [Boolean]
        # @param plan_owner_user_id [Integer]
        # @param actor_user_id [Integer]
        def private_plan_owned_by_actor?(plan_type_private:, plan_owner_user_id:, actor_user_id:)
          plan_type_private == true &&
            plan_owner_user_id.to_i == actor_user_id.to_i
        end

        # @param plan_type [String, Symbol] CultivationPlan#plan_type（"public" / "private"）
        def public_plan?(plan_type:)
          plan_type.to_s == "public"
        end
      end
    end
  end
end
