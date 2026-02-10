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
          # Ensure controller messages render in English for tests that assert English text
          # AGRR maps English to 'us' locale code in application (available_locales include 'us')
          I18n.locale = :'us'
          # Ensure application controller picks up English via cookie-based locale resolution
          cookies[:locale] = 'us'
        end
        
        teardown do
          ENV.delete('AGRR_BACKDOOR_TOKEN')
          I18n.locale = I18n.default_locale
          cookies.delete(:locale)
        end
      
      # Helper to mock external commands and BackdoorConfig.token during requests
      def with_backdoor_external_mocks
    # Stub external command output and file/socket checks to avoid real I/O
    Kernel.stub(:`, ->(cmd) {
      case cmd
      when /agrr daemon status/ then "PID: 123\n"
      when /ps -o rss= -p/ then "12345\n"
      when /ps -o etime= -p/ then "00:10:00\n"
      else ""
      end
    }) do
      File.stub(:exist?, true) do
        File.stub(:socket?, true) do
          File.stub(:executable?, true) do
            BackdoorConfig.stub(:enabled?, true) do
              BackdoorConfig.stub(:token, @token) { yield }
            end
          end
        end
      end
    end
      end
        
        test "should require authentication token for status endpoint" do
          get "/api/v1/backdoor/status"
          
          assert_response :unauthorized
          json = JSON.parse(response.body)
          expected_en = I18n.t('api.errors.backdoor.missing_token', locale: :'us')
          expected_ja = I18n.t('api.errors.backdoor.missing_token', locale: :ja)
          assert_includes [expected_en, expected_ja], json['error']
        end
        
        test "should reject invalid token" do
          get "/api/v1/backdoor/status", headers: { 'X-Backdoor-Token' => 'invalid_token' }
          
          assert_response :forbidden
          json = JSON.parse(response.body)
          expected_en = I18n.t('api.errors.backdoor.invalid_token', locale: :'us')
          expected_ja = I18n.t('api.errors.backdoor.invalid_token', locale: :ja)
          assert_includes [expected_en, expected_ja], json['error']
        end
        
        test "should accept valid token in header" do
          # ステータス本体の重い処理（ファイル/外部コマンド呼び出し）をスタブして
          # 認証 before_action のみを通す形で高速化する
          Api::V1::Backdoor::BackdoorController.any_instance.stub(:status, proc {
            render json: { success: true }
          }) do
            with_backdoor_external_mocks do
              get "/api/v1/backdoor/status", headers: { 'X-Backdoor-Token' => @token }
              assert_response :success
            end
          end
        end
        
        test "should accept valid token in params" do
          with_backdoor_external_mocks do
            get "/api/v1/backdoor/status", params: { token: @token }
            assert_response :success
          end
        end
        
        test "should return daemon status information" do
          with_backdoor_external_mocks do
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
          expected_en = I18n.t('api.errors.backdoor.not_enabled', locale: :'us')
          expected_ja = I18n.t('api.errors.backdoor.not_enabled', locale: :ja)
          assert_includes [expected_en, expected_ja], json['error']
        end
        
        # User creation tests
        test "should create user with valid parameters" do
          user_params = {
            user: {
              email: 'test@example.com',
              name: 'Test User',
              google_id: 'google123',
              admin: false
            }
          }
          
          assert_difference 'User.count', 1 do
            post "/api/v1/backdoor/users", 
                 params: user_params,
                 headers: { 'X-Backdoor-Token' => @token }
          end
          
          assert_response :created
          json = JSON.parse(response.body)
          
          assert json['success']
          assert json.key?('user')
          assert_equal 'test@example.com', json['user']['email']
          assert_equal 'Test User', json['user']['name']
          assert_equal 'google123', json['user']['google_id']
          assert_equal false, json['user']['admin']
          assert json['user'].key?('id')
          assert json['user'].key?('created_at')
        end
        
        test "should require authentication for user creation" do
          user_params = {
            user: {
              email: 'test@example.com',
              name: 'Test User',
              google_id: 'google123'
            }
          }
          
          post "/api/v1/backdoor/users", params: user_params
          
          assert_response :unauthorized
        end
        
        test "should reject user creation with invalid parameters" do
          user_params = {
            user: {
              email: 'invalid-email',
              name: '',
              google_id: ''
            }
          }
          
          assert_no_difference 'User.count' do
            post "/api/v1/backdoor/users",
                 params: user_params,
                 headers: { 'X-Backdoor-Token' => @token }
          end
          
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          
          assert_not json['success']
          assert json.key?('errors')
          assert json['errors'].is_a?(Array)
        end
        
        test "should reject user creation with duplicate email" do
          existing_user = User.create!(
            email: 'existing@example.com',
            name: 'Existing User',
            google_id: 'existing123',
            is_anonymous: false
          )
          
          user_params = {
            user: {
              email: 'existing@example.com',
              name: 'New User',
              google_id: 'new123'
            }
          }
          
          assert_no_difference 'User.count' do
            post "/api/v1/backdoor/users",
                 params: user_params,
                 headers: { 'X-Backdoor-Token' => @token }
          end
          
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          
          assert_not json['success']
          assert json.key?('errors')
        end
        
        test "should reject user creation with duplicate google_id" do
          existing_user = User.create!(
            email: 'existing@example.com',
            name: 'Existing User',
            google_id: 'existing123',
            is_anonymous: false
          )
          
          user_params = {
            user: {
              email: 'new@example.com',
              name: 'New User',
              google_id: 'existing123'
            }
          }
          
          assert_no_difference 'User.count' do
            post "/api/v1/backdoor/users",
                 params: user_params,
                 headers: { 'X-Backdoor-Token' => @token }
          end
          
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          
          assert_not json['success']
          assert json.key?('errors')
        end
        
        # User update tests
        test "should update user with valid parameters" do
          user = User.create!(
            email: 'original@example.com',
            name: 'Original User',
            google_id: 'original123',
            is_anonymous: false
          )
          
          update_params = {
            user: {
              email: 'updated@example.com',
              name: 'Updated User',
              admin: true
            }
          }
          
          patch "/api/v1/backdoor/users/#{user.id}",
                params: update_params,
                headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :success
          json = JSON.parse(response.body)
          
          assert json['success']
          assert json.key?('user')
          assert_equal 'updated@example.com', json['user']['email']
          assert_equal 'Updated User', json['user']['name']
          assert_equal true, json['user']['admin']
          assert_equal user.id, json['user']['id']
          
          user.reload
          assert_equal 'updated@example.com', user.email
          assert_equal 'Updated User', user.name
          assert_equal true, user.admin?
        end
        
        test "should require authentication for user update" do
          user = User.create!(
            email: 'test@example.com',
            name: 'Test User',
            google_id: 'test123',
            is_anonymous: false
          )
          
          update_params = {
            user: {
              name: 'Updated Name'
            }
          }
          
          patch "/api/v1/backdoor/users/#{user.id}", params: update_params
          
          assert_response :unauthorized
        end
        
        test "should return not found for non-existent user" do
          update_params = {
            user: {
              name: 'Updated Name'
            }
          }
          
          patch "/api/v1/backdoor/users/99999",
                params: update_params,
                headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :not_found
          json = JSON.parse(response.body)
          
          assert_not json['success']
          assert_equal 'User not found', json['error']
        end
        
        test "should reject user update with invalid parameters" do
          user = User.create!(
            email: 'test@example.com',
            name: 'Test User',
            google_id: 'test123',
            is_anonymous: false
          )
          
          update_params = {
            user: {
              email: 'invalid-email',
              name: ''
            }
          }
          
          patch "/api/v1/backdoor/users/#{user.id}",
                params: update_params,
                headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          
          assert_not json['success']
          assert json.key?('errors')
          assert json['errors'].is_a?(Array)
        end
        
        test "should support PUT method for user update" do
          user = User.create!(
            email: 'test@example.com',
            name: 'Test User',
            google_id: 'test123',
            is_anonymous: false
          )
          
          update_params = {
            user: {
              name: 'Updated Name'
            }
          }
          
          put "/api/v1/backdoor/users/#{user.id}",
              params: update_params,
              headers: { 'X-Backdoor-Token' => @token }
          
          assert_response :success
          json = JSON.parse(response.body)
          
          assert json['success']
          assert_equal 'Updated Name', json['user']['name']
        end
      end
    end
  end
end
