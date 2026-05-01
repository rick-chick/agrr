# frozen_string_literal: true

require "test_helper"

class UpdateReferenceWeatherDataJobTest < ActiveJob::TestCase
  test "参照農場がない場合はFetchWeatherDataJobをエンキューしない" do
    create(:farm, :user_owned, user: create(:user))

    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "2026年以降でも取得終了日が当年の今日になり暦年で2025に切り詰めない" do
    travel_to Time.zone.local(2026, 5, 1, 10, 0, 0) do
      create(:farm, :reference)

      assert_enqueued_jobs(1, only: FetchWeatherDataJob) do
        UpdateReferenceWeatherDataJob.perform_now
      end

      job_hash = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find { |j| j[:job] == FetchWeatherDataJob }
      assert job_hash, "FetchWeatherDataJob がエンキューされること"

      kwargs = ActiveJob::Arguments.deserialize(job_hash[:args]).first
      assert_equal Date.new(2026, 4, 24), kwargs[:start_date]
      assert_equal Date.new(2026, 5, 1), kwargs[:end_date]
    end
  end
end
