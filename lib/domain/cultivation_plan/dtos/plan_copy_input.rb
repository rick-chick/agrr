# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanCopyInput
        attr_reader :source_cultivation_plan_id, :new_year, :user_id, :session_id

        def initialize(source_cultivation_plan_id:, new_year:, user_id:, session_id: nil)
          @source_cultivation_plan_id = source_cultivation_plan_id
          @new_year = new_year
          @user_id = user_id
          @session_id = session_id
        end
      end
    end
  end
end
