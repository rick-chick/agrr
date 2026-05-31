# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module InternalJobs
    module Interactors
      class SchedulerWeatherBatchEnqueueInteractorTest < DomainLibTestCase
        FakeClock = Struct.new(:today)

        class RecordingSchedulePort
          include Ports::SchedulerWeatherFetchSchedulePort

          attr_reader :calls, :flushed

          def initialize
            @calls = []
            @flushed = false
          end

          def schedule_fetch(farm_id:, latitude:, longitude:, start_date:, end_date:, delay_secs:)
            @calls << {
              farm_id: farm_id,
              latitude: latitude,
              longitude: longitude,
              start_date: start_date,
              end_date: end_date,
              delay_secs: delay_secs
            }
          end

          def flush
            @flushed = true
          end
        end

        class FakeListGateway
          include Gateways::SchedulerWeatherFarmListGateway

          def initialize(reference:, user:)
            @reference = reference
            @user = user
          end

          def list_reference_farms_for_weather_update
            @reference
          end

          def list_user_farms_for_weather_update
            @user
          end
        end

        test "schedules reference and user farms then flushes" do
          ref_farm = Dtos::SchedulerWeatherFarmRow.new(
            farm_id: 1,
            latitude: 35.0,
            longitude: 139.0,
            latest_weather_date: nil
          )
          user_farm = Dtos::SchedulerWeatherFarmRow.new(
            farm_id: 2,
            latitude: 36.0,
            longitude: 140.0,
            latest_weather_date: Date.new(2026, 4, 28)
          )
          schedule_port = RecordingSchedulePort.new
          interactor = SchedulerWeatherBatchEnqueueInteractor.new(
            list_gateway: FakeListGateway.new(reference: [ ref_farm ], user: [ user_farm ]),
            schedule_port: schedule_port,
            clock: FakeClock.new(Date.new(2026, 5, 1))
          )

          interactor.call

          assert schedule_port.flushed
          assert_equal 2, schedule_port.calls.size
          assert_equal 1, schedule_port.calls[0][:farm_id]
          assert_equal Date.new(2026, 4, 24), schedule_port.calls[0][:start_date]
          assert_equal 2, schedule_port.calls[1][:farm_id]
          assert_equal Date.new(2026, 4, 29), schedule_port.calls[1][:start_date]
        end
      end
    end
  end
end
