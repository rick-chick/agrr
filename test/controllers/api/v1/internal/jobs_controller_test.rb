# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Internal
      class JobsControllerTest < ActionDispatch::IntegrationTest
        setup do
          # Set a test token for all tests
          @token = 'test_scheduler_token_12345'
          ENV['SCHEDULER_AUTH_TOKEN'] = @token
        end
        
        teardown do
          ENV.delete('SCHEDULER_AUTH_TOKEN')
        end
        
        test "should require authentication token for trigger_weather_update endpoint" do
          post "/api/v1/internal/jobs/trigger_weather_update"
          
          assert_response :unauthorized
          json = JSON.parse(response.body)
          assert_equal 'Missing authentication token', json['error']
        end
        
        test "should reject invalid token" do
          post "/api/v1/internal/jobs/trigger_weather_update", 
               headers: { 'X-Scheduler-Token' => 'invalid_token' }
          
          assert_response :forbidden
          json = JSON.parse(response.body)
          assert_equal 'Invalid authentication token', json['error']
        end
        
        test "should accept valid token in X-Scheduler-Token header" do
          assert_enqueued_with(job: UpdateReferenceWeatherDataJob) do
            assert_enqueued_with(job: UpdateUserFarmsWeatherDataJob) do
              post "/api/v1/internal/jobs/trigger_weather_update",
                   headers: { 'X-Scheduler-Token' => @token }
            end
          end
          
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal true, json['success']
          assert_equal 'Weather update jobs enqueued', json['message']
          assert json.key?('timestamp')
        end
        
        test "should accept valid token in Authorization header" do
          assert_enqueued_with(job: UpdateReferenceWeatherDataJob) do
            assert_enqueued_with(job: UpdateUserFarmsWeatherDataJob) do
              post "/api/v1/internal/jobs/trigger_weather_update",
                   headers: { 'Authorization' => "Bearer #{@token}" }
            end
          end
          
          assert_response :success
        end
        
        test "should accept valid token in params" do
          assert_enqueued_with(job: UpdateReferenceWeatherDataJob) do
            assert_enqueued_with(job: UpdateUserFarmsWeatherDataJob) do
              post "/api/v1/internal/jobs/trigger_weather_update",
                   params: { token: @token }
            end
          end
          
          assert_response :success
        end
        
        test "should return service unavailable when token is not configured" do
          ENV.delete('SCHEDULER_AUTH_TOKEN')
          
          post "/api/v1/internal/jobs/trigger_weather_update",
               headers: { 'X-Scheduler-Token' => @token }
          
          assert_response :service_unavailable
          json = JSON.parse(response.body)
          assert_equal 'Authentication not configured', json['error']
        end
        
        test "should handle errors gracefully" do
          # ジョブのエンキュー時にエラーが発生した場合をシミュレート
          UpdateReferenceWeatherDataJob.stub(:perform_later, -> { raise StandardError.new("Job error") }) do
            post "/api/v1/internal/jobs/trigger_weather_update",
                 headers: { 'X-Scheduler-Token' => @token }
            
            assert_response :internal_server_error
            json = JSON.parse(response.body)
            assert_equal false, json['success']
            assert_equal 'Job error', json['error']
          end
        end
        
        test "should enqueue both jobs when authenticated" do
          assert_enqueued_jobs(2) do
            post "/api/v1/internal/jobs/trigger_weather_update",
                 headers: { 'X-Scheduler-Token' => @token }
          end
          
          assert_response :success
          
          # エンキューされたジョブの種類を確認
          enqueued_job_classes = enqueued_jobs.map { |j| j[:job] }
          assert_includes enqueued_job_classes, UpdateReferenceWeatherDataJob
          assert_includes enqueued_job_classes, UpdateUserFarmsWeatherDataJob
        end
      end
    end
  end
end

