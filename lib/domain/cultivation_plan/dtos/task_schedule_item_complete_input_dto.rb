# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作業予定の実績登録（complete）入力。Strong params の Hash と注入 clock から組み立てる。
      class TaskScheduleItemCompleteInputDto
        attr_reader :actual_date, :actual_notes, :completed_at

        def initialize(actual_date:, actual_notes:, completed_at:)
          @actual_date = actual_date
          @actual_notes = actual_notes
          @completed_at = completed_at
        end

        # @param completion_params [Hash] :actual_date（任意）, :notes（任意）。キーは文字列でも可。
        # @param clock [#today, #now] 例: ActiveSupport::TimeZone
        def self.from_completion_params(completion_params, clock:)
          h = completion_params.to_h.symbolize_keys
          actual_date = coerce_actual_date(h[:actual_date], clock: clock)
          new(
            actual_date: actual_date,
            actual_notes: h[:notes],
            completed_at: clock.now
          )
        rescue ArgumentError => e
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            e.message,
            errors: { "actual_date" => [ e.message ] }
          )
        end

        def self.coerce_actual_date(raw, clock:)
          return clock.today if raw.blank?

          case raw
          when Date
            raw
          when Time, ActiveSupport::TimeWithZone
            raw.to_date
          else
            Date.parse(raw.to_s)
          end
        end
        private_class_method :coerce_actual_date
      end
    end
  end
end
