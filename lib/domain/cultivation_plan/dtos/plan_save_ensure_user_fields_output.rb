# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserFieldsOutput
        attr_reader :field_ids, :skipped_field_ids

        # @param field_ids [Array<Integer>]
        # @param skipped_field_ids [Array<Integer>]
        def initialize(field_ids:, skipped_field_ids: [])
          @field_ids = Array(field_ids).map(&:to_i).freeze
          @skipped_field_ids = Array(skipped_field_ids).map(&:to_i).freeze
          freeze
        end
      end
    end
  end
end
