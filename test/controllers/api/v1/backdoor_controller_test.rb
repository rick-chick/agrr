# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Backdoor
      class BackdoorControllerTest < ActionDispatch::IntegrationTest
        setup do
          # Set a test token for all tests
          @token = 'test_backdoor_token_12345'
          ENV['AGRR_BACKDOOR_TOKEN'] = @token
        end
        
        teardown do
          ENV.delete('AGRR_BACKDOOR_TOKEN')
        end
        
        test "should require authentication token for status endpoint" do
          get "/api/v1/backdoor/status"
          
          assert_response :unauthorized
          json = JSON.parse(response.body)
          assert_equal 'Missing authentication token', json['error']
        end
        
        test "should reject invalid token" do
          get "/api/v1/backdoor/status", headers: { 'X-Backdoor-Token' => 'invalid_token' }
          
          assert_response :forbidden
          json = JSON.parse(response.body)
          assert_equal 'Invalid authentication token', json['error']
        end
        
        test "should accept valid token in header" do
          get "/api/v1/backdoor/status", headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :success
        end
        
        test "should accept valid token in params" do
          get "/api/v1/backdoor/status", params: { token: @token }
          
          assert_response :success
        end
        
        test "should return daemon status information" do
          get "/api/v1/backdoor/status", headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :success
          json = JSON.parse(response.body)
          
          # Check response structure
          assert json.key?('timestamp')
          assert json.key?('daemon')
          assert json.key?('binary')
          assert json.key?('status_output')
          assert json.key?('process')
          assert json.key?('service_available')
          
          # Check daemon info
          assert json['daemon'].key?('running')
          assert json['daemon'].key?('socket_exists')
          assert json['daemon'].key?('socket_path')
          
          # Check binary info
          assert json['binary'].key?('exists')
          assert json['binary'].key?('executable')
          assert json['binary'].key?('path')
        end
        
        test "should return health check information" do
          get "/api/v1/backdoor/health", headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :success
          json = JSON.parse(response.body)
          
          assert_equal 'ok', json['status']
          assert json.key?('timestamp')
          assert_equal 'Backdoor API is active', json['message']
        end
        
        test "health endpoint should require authentication" do
          get "/api/v1/backdoor/health"
          
          assert_response :unauthorized
        end
        
        test "should return service unavailable when backdoor is disabled" do
          # Temporarily disable backdoor
          ENV.delete('AGRR_BACKDOOR_TOKEN')
          
          get "/api/v1/backdoor/health"
          
          assert_response :service_unavailable
          json = JSON.parse(response.body)
          assert_includes json['error'], 'not enabled'
        end
      end
    end
  end
end
