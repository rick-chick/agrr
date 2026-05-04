# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Plans
      class TaskSchedulesControllerTest < ActionDispatch::IntegrationTest
        include ActiveSupport::Testing::TimeHelpers

        setup do
          travel_to Time.zone.local(2025, 3, 10, 9, 0, 0)

          @user = create(:user)
          sign_in_as @user

          @plan = create(:cultivation_plan, :completed, user: @user, farm: create(:farm, user: @user))
          @field_cultivation = create(:field_cultivation, cultivation_plan: @plan)

          @general_schedule = create(:task_schedule,
            cultivation_plan: @plan,
            field_cultivation: @field_cultivation,
            category: "general")

          create(:task_schedule_item,
            task_schedule: @general_schedule,
            scheduled_date: Date.current + 1.day,
            name: "本週作業")
        end

        teardown do
          travel_back
        end

        test "returns task schedule json for the authenticated owner's plan" do
          get "/api/v1/plans/#{@plan.id}/task_schedule",
              headers: { "Accept" => "application/json" }

          assert_response :success
          data = JSON.parse(response.body)
          assert_equal @plan.id, data["plan"]["id"]
          assert_equal "2025-03-10", data["week"]["start_date"]
          assert_equal 1, data["fields"].size
          general_tasks = data["fields"].first.dig("schedules", "general")
          assert_equal [ "本週作業" ], general_tasks.map { |task| task["name"] }
        end

        test "returns 404 when plan belongs to another user" do
          other = create(:user)
          other_plan = create(:cultivation_plan, :completed, user: other, farm: create(:farm, user: other))

          get "/api/v1/plans/#{other_plan.id}/task_schedule",
              headers: { "Accept" => "application/json" }

          assert_response :not_found
        end

        test "returns 401 when not authenticated" do
          cookies.delete("session_id")

          get "/api/v1/plans/#{@plan.id}/task_schedule",
              headers: { "Accept" => "application/json" }

          assert_response :unauthorized
        end
      end
    end
  end
end
