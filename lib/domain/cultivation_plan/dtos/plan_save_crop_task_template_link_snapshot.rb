# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveUserAgriculturalTaskGateway の crop_task_template find 戻り値。
      class PlanSaveCropTaskTemplateLinkSnapshot
        attr_reader :id

        def initialize(id:)
          @id = id.to_i
          freeze
        end
      end
    end
  end
end
