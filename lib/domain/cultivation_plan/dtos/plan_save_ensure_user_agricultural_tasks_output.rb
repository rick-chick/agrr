# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserAgriculturalTasksOutput
        attr_reader :user_agricultural_task_ids,
                    :skipped_agricultural_task_ids,
                    :reference_agricultural_task_id_to_user_task_id

        def initialize(
          user_agricultural_task_ids:,
          skipped_agricultural_task_ids: [],
          reference_agricultural_task_id_to_user_task_id: {}
        )
          @user_agricultural_task_ids = Array(user_agricultural_task_ids).map(&:to_i).freeze
          @skipped_agricultural_task_ids = Array(skipped_agricultural_task_ids).map(&:to_i).freeze
          @reference_agricultural_task_id_to_user_task_id =
            reference_agricultural_task_id_to_user_task_id.transform_keys(&:to_i)
                                                           .transform_values(&:to_i)
                                                           .freeze
          freeze
        end
      end
    end
  end
end
