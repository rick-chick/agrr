# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'ostruct'

module Api
  module V1
    module Crops
      class CropFertilizeProfilesApiControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          sign_in_as @user
          @crop = create(:crop, :tomato, user: @user)
          @profile = create(:crop_fertilize_profile, crop: @crop)
        end

        test 'should show crop fertilize profile' do
          get api_v1_crop_crop_fertilize_profile_path(@crop, @profile),
              headers: { 'Accept' => 'application/json' }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal @profile.id, json_response['id']
          assert_equal @profile.crop_id, json_response['crop_id']
          assert_equal @profile.total_n, json_response['total_n']
          assert_equal @profile.total_p, json_response['total_p']
          assert_equal @profile.total_k, json_response['total_k']
        end

        test 'should create crop fertilize profile' do
          assert_difference('CropFertilizeProfile.count') do
            post api_v1_crop_crop_fertilize_profiles_path(@crop),
                 params: {
                   crop_fertilize_profile: {
                     total_n: 18.0,
                     total_p: 5.0,
                     total_k: 12.0,
                     confidence: 0.8,
                     notes: 'Test profile'
                   }
                 },
                 headers: { 'Accept' => 'application/json' }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal 18.0, json_response['total_n']
          assert_equal 5.0, json_response['total_p']
          assert_equal 12.0, json_response['total_k']
          assert_equal 0.8, json_response['confidence']
        end

        test 'should create crop fertilize profile with applications' do
          assert_difference('CropFertilizeProfile.count', 1) do
            assert_difference('CropFertilizeApplication.count', 2) do
              post api_v1_crop_crop_fertilize_profiles_path(@crop),
                   params: {
                     crop_fertilize_profile: {
                       total_n: 18.0,
                       total_p: 5.0,
                       total_k: 12.0,
                       confidence: 0.8,
                       crop_fertilize_applications_attributes: [
                         {
                           application_type: 'basal',
                           count: 1,
                           schedule_hint: 'pre-plant',
                           total_n: 6.0,
                           total_p: 2.0,
                           total_k: 3.0
                         },
                         {
                           application_type: 'topdress',
                           count: 2,
                           schedule_hint: 'fruiting',
                           total_n: 12.0,
                           total_p: 3.0,
                           total_k: 9.0,
                           per_application_n: 6.0,
                           per_application_p: 1.5,
                           per_application_k: 4.5
                         }
                       ]
                     }
                   },
                   headers: { 'Accept' => 'application/json' }
            end
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response['applications'].count

          basal = json_response['applications'].find { |a| a['application_type'] == 'basal' }
          assert_equal 1, basal['count']
          assert_nil basal['per_application']

          topdress = json_response['applications'].find { |a| a['application_type'] == 'topdress' }
          assert_equal 2, topdress['count']
          assert_equal 6.0, topdress['per_application']['n']
        end

        test 'should update crop fertilize profile' do
          patch api_v1_crop_crop_fertilize_profile_path(@crop, @profile),
                params: {
                  crop_fertilize_profile: {
                    total_n: 20.0,
                    total_p: 6.0,
                    total_k: 14.0
                  }
                },
                headers: { 'Accept' => 'application/json' }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 20.0, json_response['total_n']
          
          @profile.reload
          assert_equal 20.0, @profile.total_n
        end

        test 'should destroy crop fertilize profile' do
          assert_difference('CropFertilizeProfile.count', -1) do
            delete api_v1_crop_crop_fertilize_profile_path(@crop, @profile),
                   headers: { 'Accept' => 'application/json' }
          end

          assert_response :no_content
        end

        test 'should handle sources as comma separated string' do
          post api_v1_crop_crop_fertilize_profiles_path(@crop),
               params: {
                 crop_fertilize_profile: {
                   total_n: 18.0,
                   total_p: 5.0,
                   total_k: 12.0,
                   sources: 'source1, source2, source3'
                 }
               },
               headers: { 'Accept' => 'application/json' }

          profile = CropFertilizeProfile.last
          assert_equal ['source1', 'source2', 'source3'], profile.sources
        end

        test 'should not allow access to other users crop' do
          other_user = create(:user)
          other_crop = create(:crop, user: other_user)
          other_profile = create(:crop_fertilize_profile, crop: other_crop)

          get api_v1_crop_crop_fertilize_profile_path(other_crop, other_profile),
              headers: { 'Accept' => 'application/json' }

          assert_response :forbidden
        end

        test 'should allow access to reference crop' do
          reference_crop = create(:crop, :tomato, is_reference: true)
          reference_profile = create(:crop_fertilize_profile, crop: reference_crop)

          get api_v1_crop_crop_fertilize_profile_path(reference_crop, reference_profile),
              headers: { 'Accept' => 'application/json' }

          assert_response :success
        end

        test 'should render errors on invalid create' do
          assert_no_difference('CropFertilizeProfile.count') do
            post api_v1_crop_crop_fertilize_profiles_path(@crop),
                 params: {
                   crop_fertilize_profile: {
                     total_n: nil,
                     total_p: 5.0,
                     total_k: 12.0
                   }
                 },
                 headers: { 'Accept' => 'application/json' }
          end

          assert_response :unprocessable_entity
          json_response = JSON.parse(response.body)
          assert json_response['error'].present?
        end

        test 'should return correct json structure' do
          profile_with_apps = create(:crop_fertilize_profile, :with_applications, crop: @crop)

          get api_v1_crop_crop_fertilize_profile_path(@crop, profile_with_apps),
              headers: { 'Accept' => 'application/json' }

          assert_response :success
          json_response = JSON.parse(response.body)
          
          assert_equal profile_with_apps.id, json_response['id']
          assert_equal @crop.id, json_response['crop_id']
          assert json_response['applications'].is_a?(Array)
          assert_equal 2, json_response['applications'].count
          
          application = json_response['applications'].first
          assert application.key?('id')
          assert application.key?('application_type')
          assert application.key?('count')
          assert application.key?('nutrients')
          assert_equal 'n', application['nutrients'].keys.first
        end

        # ai_create テスト: 登録時は常に新規作成（既存プロファイルがあっても新規作成）
        test 'ai_create should always create new profile even if existing profile exists' do
          # 既存のプロファイルを作成
          existing_profile = create(:crop_fertilize_profile, crop: @crop, total_n: 15.0, total_p: 4.0, total_k: 10.0)
          existing_profile_id = existing_profile.id
          
          # agrrコマンドの出力をモック
          agrr_output = {
            "success" => true,
            "profile" => {
              "totals" => { "N" => 18.0, "P" => 5.0, "K" => 12.0 },
              "applications" => [
                {
                  "type" => "basal",
                  "count" => 1,
                  "schedule_hint" => "pre-plant",
                  "nutrients" => { "N" => 6.0, "P" => 2.0, "K" => 3.0 }
                }
              ],
              "sources" => ["agrr-ai"],
              "confidence" => 0.8,
              "notes" => "AI generated profile"
            }
          }.to_json

          Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
            assert_difference('CropFertilizeProfile.count', 1) do
              post ai_create_api_v1_crop_crop_fertilize_profiles_path(@crop),
                   headers: { 'Accept' => 'application/json' }
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert json_response['success']
            assert_equal 18.0, json_response['total_n']
            assert_equal 5.0, json_response['total_p']
            assert_equal 12.0, json_response['total_k']
            
            # 既存プロファイルが更新されていないことを確認
            existing_profile.reload
            assert_equal 15.0, existing_profile.total_n, "既存プロファイルは更新されてはいけない"
            assert_equal existing_profile_id, existing_profile.id
            
            # 新しいプロファイルが作成されていることを確認
            new_profile = CropFertilizeProfile.find(json_response['profile_id'])
            assert_not_equal existing_profile_id, new_profile.id, "新しいプロファイルが作成される必要がある"
            assert_equal 18.0, new_profile.total_n
          end
        end

        test 'ai_create should create new profile with applications' do
          agrr_output = {
            "success" => true,
            "profile" => {
              "totals" => { "N" => 20.0, "P" => 6.0, "K" => 14.0 },
              "applications" => [
                {
                  "type" => "basal",
                  "count" => 1,
                  "schedule_hint" => "pre-plant",
                  "nutrients" => { "N" => 8.0, "P" => 3.0, "K" => 4.0 }
                },
                {
                  "type" => "topdress",
                  "count" => 2,
                  "schedule_hint" => "fruiting",
                  "nutrients" => { "N" => 12.0, "P" => 3.0, "K" => 10.0 },
                  "per_application" => { "N" => 6.0, "P" => 1.5, "K" => 5.0 }
                }
              ],
              "sources" => ["agrr-ai"],
              "confidence" => 0.9,
              "notes" => "Test profile"
            }
          }.to_json

          Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
            assert_difference('CropFertilizeProfile.count', 1) do
              assert_difference('CropFertilizeApplication.count', 2) do
                post ai_create_api_v1_crop_crop_fertilize_profiles_path(@crop),
                     headers: { 'Accept' => 'application/json' }
              end
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert json_response['success']
            assert_equal 20.0, json_response['total_n']
            assert_equal 2, json_response['applications_count']
            
            profile = CropFertilizeProfile.find(json_response['profile_id'])
            assert_equal 2, profile.crop_fertilize_applications.count
          end
        end

        # ai_update テスト: 編集時は既存プロファイルを更新
        test 'ai_update should update existing profile' do
          profile_to_update = create(:crop_fertilize_profile, crop: @crop, total_n: 15.0, total_p: 4.0, total_k: 10.0)
          profile_id = profile_to_update.id
          
          # 既存のapplicationsを作成
          create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile_to_update)
          
          agrr_output = {
            "success" => true,
            "profile" => {
              "totals" => { "N" => 20.0, "P" => 6.0, "K" => 14.0 },
              "applications" => [
                {
                  "type" => "basal",
                  "count" => 1,
                  "schedule_hint" => "pre-plant-updated",
                  "nutrients" => { "N" => 8.0, "P" => 3.0, "K" => 4.0 }
                },
                {
                  "type" => "topdress",
                  "count" => 3,
                  "schedule_hint" => "fruiting",
                  "nutrients" => { "N" => 12.0, "P" => 3.0, "K" => 10.0 },
                  "per_application" => { "N" => 4.0, "P" => 1.0, "K" => 3.33 }
                }
              ],
              "sources" => ["agrr-ai-updated"],
              "confidence" => 0.95,
              "notes" => "Updated profile"
            }
          }.to_json

          initial_app_count = profile_to_update.crop_fertilize_applications.count
          
          Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
            assert_no_difference('CropFertilizeProfile.count') do
              post ai_update_api_v1_crop_crop_fertilize_profile_path(@crop, profile_to_update),
                   headers: { 'Accept' => 'application/json' }
            end

            assert_response :ok
            json_response = JSON.parse(response.body)
            assert json_response['success']
            assert_equal profile_id, json_response['profile_id'], "同じプロファイルIDが返される必要がある"
            assert_equal 20.0, json_response['total_n']
            assert_equal 6.0, json_response['total_p']
            assert_equal 14.0, json_response['total_k']
            assert_equal 2, json_response['applications_count']
            
            # プロファイルが更新されていることを確認
            profile_to_update.reload
            assert_equal profile_id, profile_to_update.id
            assert_equal 20.0, profile_to_update.total_n
            assert_equal 0.95, profile_to_update.confidence
            assert_equal ["agrr-ai-updated"], profile_to_update.sources
            assert_equal 2, profile_to_update.crop_fertilize_applications.count
          end
        end

        test 'ai_create should handle daemon not running error' do
          error_output = {
            "success" => false,
            "error" => "AGRRサービスが起動していません",
            "code" => "daemon_not_running"
          }.to_json

          Open3.stub :capture3, [error_output, "", OpenStruct.new(success?: true)] do
            assert_no_difference('CropFertilizeProfile.count') do
              post ai_create_api_v1_crop_crop_fertilize_profiles_path(@crop),
                   headers: { 'Accept' => 'application/json' }
            end

            assert_response :unprocessable_entity
            json_response = JSON.parse(response.body)
            assert json_response['error'].present?
          end
        end
      end
    end
  end
end

