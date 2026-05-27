# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserFertilizesOutput
        attr_reader :user_fertilize_ids, :skipped_fertilize_ids

        # @param user_fertilize_ids [Array<Integer>]
        # @param skipped_fertilize_ids [Array<Integer>]
        def initialize(user_fertilize_ids:, skipped_fertilize_ids: [])
          @user_fertilize_ids = Array(user_fertilize_ids).map(&:to_i).freeze
          @skipped_fertilize_ids = Array(skipped_fertilize_ids).map(&:to_i).freeze
          freeze
        end
      end
    end
  end
end
