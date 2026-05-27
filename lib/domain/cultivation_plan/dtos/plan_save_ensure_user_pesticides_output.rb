# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserPesticidesOutput
        attr_reader :user_pesticide_ids, :skipped_pesticide_ids

        # @param user_pesticide_ids [Array<Integer>]
        # @param skipped_pesticide_ids [Array<Integer>]
        def initialize(user_pesticide_ids:, skipped_pesticide_ids: [])
          @user_pesticide_ids = Array(user_pesticide_ids).map(&:to_i).freeze
          @skipped_pesticide_ids = Array(skipped_pesticide_ids).map(&:to_i).freeze
          freeze
        end
      end
    end
  end
end
