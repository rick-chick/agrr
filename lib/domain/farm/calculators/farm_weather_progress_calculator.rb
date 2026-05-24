# frozen_string_literal: true

module Domain
  module Farm
    module Calculators
      module FarmWeatherProgressCalculator
        START_YEAR = 2000
        BLOCK_SIZE = 5

        module_function

        def progress_percent(fetched:, total:)
          return 0 if total.to_i.zero?

          (fetched.to_f / total * 100).round
        end

        def normalize_longitude(longitude)
          return nil if longitude.nil?

          ((longitude.to_f + 180) % 360) - 180
        end

        def start_fetch_attrs(as_of:)
          end_year = as_of.year
          total_years = end_year - START_YEAR + 1
          total_blocks = ((total_years - 1) / BLOCK_SIZE) + 1
          {
            weather_data_status: "fetching",
            weather_data_fetched_years: 0,
            weather_data_total_years: total_blocks,
            weather_data_last_error: nil
          }
        end

        # @return [Hash, Boolean] attrs for update, whether broadcast throttle allows timestamp update
        def next_after_block(fetched:, total:, last_broadcast_at:, current_time:, throttle_seconds: 0.5)
          return [ {}, false ] if total.to_i.zero?
          return [ {}, false ] if fetched.to_i >= total.to_i

          new_fetched = fetched.to_i + 1
          throttle = Domain::Farm::Policies::FarmBroadcastThrottlePolicy.should_update_broadcast_time?(
            last_broadcast_at: last_broadcast_at,
            current_time: current_time,
            throttle_seconds: throttle_seconds
          )

          attrs = { weather_data_fetched_years: new_fetched }
          attrs[:weather_data_status] = "completed" if new_fetched >= total.to_i
          attrs[:last_broadcast_at] = current_time if throttle

          [ attrs, throttle ]
        end

        def failed_attrs(error_message:)
          {
            weather_data_status: "failed",
            weather_data_last_error: error_message
          }
        end

        def weather_fetch_blocks(as_of:)
          end_year = as_of.year
          blocks = []
          current_year = START_YEAR
          while current_year <= end_year
            block_end_year = [current_year + BLOCK_SIZE - 1, end_year].min
            blocks << {
              start_date: Date.new(current_year, 1, 1),
              end_date: [Date.new(block_end_year, 12, 31), as_of].min
            }
            current_year += BLOCK_SIZE
          end
          blocks
        end

        def reset_for_coordinate_change_attrs
          {
            weather_location_id: nil,
            weather_data_status: "pending",
            weather_data_fetched_years: 0,
            weather_data_total_years: 0,
            weather_data_last_error: nil
          }
        end
      end
    end
  end
end
