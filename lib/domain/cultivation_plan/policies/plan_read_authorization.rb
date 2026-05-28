# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # ORM 非依存の栽培計画読み取り可否（private 本人 / public）。
      module PlanReadAuthorization
        module_function

        # @param plan_type [String, Symbol] CultivationPlan#plan_type（"public" / "private"）
        def public_plan?(plan_type:)
          plan_type.to_s == "public"
        end
      end
    end
  end
end
