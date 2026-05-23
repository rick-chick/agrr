# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationPlanAccessContext
        attr_reader :field_cultivation_id, :plan_type_public, :plan_type_private, :plan_user_id

        def initialize(field_cultivation_id:, plan_type_public:, plan_type_private:, plan_user_id:)
          @field_cultivation_id = field_cultivation_id
          @plan_type_public = plan_type_public
          @plan_type_private = plan_type_private
          @plan_user_id = plan_user_id
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
