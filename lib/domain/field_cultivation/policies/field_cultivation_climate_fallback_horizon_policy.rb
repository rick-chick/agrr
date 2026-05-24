# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      module FieldCultivationClimateFallbackHorizonPolicy
        module_function

        def prediction_days(completion_date:, training_end_date:)
          (completion_date - training_end_date).to_i
        end

        def use_prediction_branch?(prediction_days:)
          prediction_days.positive?
        end
      end
    end
  end
end
