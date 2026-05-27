# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePestControlMethodRow
        attr_reader :method_type, :method_name, :description, :timing_hint

        def initialize(method_type:, method_name:, description:, timing_hint:)
          @method_type = method_type
          @method_name = method_name
          @description = description
          @timing_hint = timing_hint
          freeze
        end
      end
    end
  end
end
