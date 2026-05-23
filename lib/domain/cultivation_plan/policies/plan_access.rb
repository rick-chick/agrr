# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # 栽培計画（private / public）のアクセス。旧 PlanPolicy と同一ルール。
      class PlanAccess
        def self.private_scope(user)
          ::CultivationPlan.plan_type_private.by_user(user)
        end

        def self.find_private_owned!(user, id)
          plan = ::CultivationPlan.find_by(id: id)
          raise Domain::Shared::Exceptions::RecordNotFound, "CultivationPlan not found" unless plan

          allowed = plan.plan_type_private? && plan.user_id == user.id
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          plan
        end

        def self.public_scope
          ::CultivationPlan.plan_type_public
        end

        def self.find_public!(id)
          plan = ::CultivationPlan.find_by(id: id)
          raise Domain::Shared::Exceptions::RecordNotFound, "CultivationPlan not found" unless plan

          raise Domain::Shared::Policies::PolicyPermissionDenied unless plan.plan_type_public?

          plan
        end
      end
    end
  end
end
