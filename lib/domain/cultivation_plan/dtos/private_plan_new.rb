# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画ウィザード「農場選択」HTML 用。ActiveRecord は含めない。
      class PrivatePlanNew
        attr_reader :farm_choices, :default_plan_name

        # @param farm_choices [Array<Domain::CultivationPlan::Dtos::PrivatePlanNewFarmChoice>]
        # @param default_plan_name [String]
        def initialize(farm_choices:, default_plan_name:)
          @farm_choices = farm_choices
          @default_plan_name = default_plan_name
        end

        def empty?
          @farm_choices.empty?
        end
      end
    end
  end
end
