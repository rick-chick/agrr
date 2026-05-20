# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # `CultivationPlanAdjustGateway#execute` の戻り。
      class CultivationPlanRestAdjustOutcome
        OUTCOME_CROP_MISSING_GROWTH_STAGES = :crop_missing_growth_stages
        OUTCOME_ADJUST_RESULT = :adjust_result
        OUTCOME_NOT_FOUND = :not_found
        OUTCOME_RECORD_INVALID = :record_invalid
        OUTCOME_UNEXPECTED = :unexpected

        attr_reader :outcome, :crop_name, :adjust_payload, :message

        def initialize(outcome:, crop_name: nil, adjust_payload: nil, message: nil)
          @outcome = outcome
          @crop_name = crop_name
          @adjust_payload = adjust_payload
          @message = message
        end

        def self.crop_missing_growth_stages(crop_name:)
          new(outcome: OUTCOME_CROP_MISSING_GROWTH_STAGES, crop_name: crop_name)
        end

        def self.adjust_result(payload)
          new(outcome: OUTCOME_ADJUST_RESULT, adjust_payload: payload)
        end

        def self.not_found
          new(outcome: OUTCOME_NOT_FOUND)
        end

        def self.record_invalid(message:)
          new(outcome: OUTCOME_RECORD_INVALID, message: message)
        end

        def self.unexpected(message:)
          new(outcome: OUTCOME_UNEXPECTED, message: message)
        end

        def crop_missing_growth_stages?
          outcome == OUTCOME_CROP_MISSING_GROWTH_STAGES
        end

        def adjust_result?
          outcome == OUTCOME_ADJUST_RESULT
        end

        def not_found?
          outcome == OUTCOME_NOT_FOUND
        end

        def record_invalid?
          outcome == OUTCOME_RECORD_INVALID
        end

        def unexpected?
          outcome == OUTCOME_UNEXPECTED
        end
      end
    end
  end
end
