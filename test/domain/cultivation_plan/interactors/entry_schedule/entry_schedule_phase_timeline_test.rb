# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain::CultivationPlan::Interactors::EntrySchedule
  class EntrySchedulePhaseTimelineTest < DomainLibTestCase
    setup do
      @start_d = Date.new(2026, 7, 1)
      @end_d = Date.new(2027, 8, 31)
      @result = WindowService::Result.new(
        eligible: true,
        sowing_windows: [ { start_date: @start_d, end_date: @end_d } ],
        transplant_windows: [ { start_date: @start_d, end_date: @end_d } ],
        reason_parts: {
          source: "agrr_optimize_period",
          optimal_start_date: @start_d.iso8601,
          completion_date: @end_d.iso8601,
          growth_days: 100,
          gdd: "1000"
        },
        sowing_stage_id: nil,
        transplant_stage_id: nil,
        weather_end_date: @end_d
      )
    end

    test "chart_windows splits agrr_optimize_period into distinct sowing vs transplant quarters" do
      clock = Struct.new(:today).new(Date.new(2026, 5, 1))
      timeline = EntrySchedulePhaseTimeline.new(
        translator: ->(key, **opts) { I18n.t(key, **opts) },
        clock: clock
      )
      # agrr_optimize_period 経路は crop を参照しないため nil で十分。
      cw = timeline.chart_windows(nil, @result)
      sow = cw[:sowing_windows].first
      tr = cw[:transplant_windows].first

      assert sow
      assert tr
      assert_operator sow[:end_date], :<=, tr[:end_date]
      assert_operator sow[:end_date], :<, @end_d
      refute_equal [ sow[:start_date], sow[:end_date] ], [ tr[:start_date], tr[:end_date] ]
    end
  end
end
