# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      class PlanSaveUserAgriculturalTaskMappingAdapter <
          Domain::CultivationPlan::Ports::UserAgriculturalTaskMappingPort
        def initialize(ctx)
          @mapper = Mappers::AgriculturalTaskMapper.new(ctx)
        end

        def user_task_id_for(reference_task_id:)
          @mapper.user_agricultural_task_id_for(reference_task_id)
        end
      end
    end
  end
end
