# frozen_string_literal: true

module Domain
  module PublicPlan
    module Services
      # エントリ API の予測終端日。未指定・パース失敗時は reference_date の年末（docs/planning/crop_schedule_entry_weather_initialization.md）
      class EntrySchedulePredictionEndDate
        def self.parse(prediction_end_date_raw, reference_date:)
          return reference_date.end_of_year if prediction_end_date_raw.blank?

          Date.iso8601(prediction_end_date_raw.to_s)
        rescue ArgumentError, TypeError, Date::Error
          reference_date.end_of_year
        end
      end
    end
  end
end
