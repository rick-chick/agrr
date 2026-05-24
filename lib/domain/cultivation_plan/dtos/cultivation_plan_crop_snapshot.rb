# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST add_crop: cultivation_plan_crops 行の永続化結果。
      class CultivationPlanCropSnapshot
        attr_reader :id, :display_name

        def initialize(id:, display_name:)
          @id = id
          @display_name = display_name
          freeze
        end
      end
    end
  end
end
