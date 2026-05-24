# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskScheduleItemAmountSnapshot
        attr_reader :amount, :amount_unit, :scheduled_date

        def initialize(amount:, amount_unit:, scheduled_date:)
          @amount = amount
          @amount_unit = amount_unit
          @scheduled_date = scheduled_date
        end
      end
    end
  end
end
