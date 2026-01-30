# frozen_string_literal: true

module Api
  module V1
    class PlansController < BaseController
      def index
        plans = CultivationPlan.plan_type_private.by_user(current_user).order(created_at: :desc)
        render json: plans.map { |plan| serialize_plan(plan) }
      end

      def show
        plan = CultivationPlan.plan_type_private.by_user(current_user).find(params[:id])
        render json: serialize_plan(plan)
      end

      private

      def serialize_plan(plan)
        {
          id: plan.id,
          name: plan.display_name,
          status: plan.status
        }
      end
    end
  end
end
