# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 圃場栽培と親 CultivationPlan の閲覧・更新可否判定用スナップショット。
      class FieldCultivationPlanAccessSnapshot
        attr_reader :field_cultivation_id, :plan_type_public, :plan_type_private, :plan_user_id

        def initialize(field_cultivation_id:, plan_type_public:, plan_type_private:, plan_user_id:)
          @field_cultivation_id = field_cultivation_id
          @plan_type_public = plan_type_public
          @plan_type_private = plan_type_private
          @plan_user_id = plan_user_id
          freeze
        end

        def plan_type_public?
          plan_type_public
        end

        def plan_type_private?
          plan_type_private
        end
      end
    end
  end
end
