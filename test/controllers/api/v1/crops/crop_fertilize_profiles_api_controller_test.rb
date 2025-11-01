# frozen_string_literal: true

require 'test_helper'

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
      end
    end
  end
end

