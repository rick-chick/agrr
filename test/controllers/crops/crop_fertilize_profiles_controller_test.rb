# frozen_string_literal: true

require 'test_helper'

module Crops
  class CropFertilizeProfilesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      sign_in_as @user
      @crop = create(:crop, :tomato, user: @user)
      @profile = create(:crop_fertilize_profile, crop: @crop)
    end

    test 'should show crop fertilize profile' do
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
    end

    test 'should get new' do
      get new_crop_crop_fertilize_profile_path(@crop)
      assert_response :success
    end

    test 'should get edit' do
      get edit_crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
    end

    test 'should create crop fertilize profile' do
      assert_difference('CropFertilizeProfile.count') do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            total_n: 18.0,
            total_p: 5.0,
            total_k: 12.0,
            confidence: 0.8,
            notes: 'Test profile'
          }
        }
      end

      assert_redirected_to crop_path(@crop)
    end

    test 'should create crop fertilize profile with applications' do
      assert_difference('CropFertilizeProfile.count', 1) do
        assert_difference('CropFertilizeApplication.count', 2) do
          post crop_crop_fertilize_profiles_path(@crop), params: {
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
          }
        end
      end

      assert_redirected_to crop_path(@crop)
      profile = CropFertilizeProfile.last
      assert_equal 2, profile.crop_fertilize_applications.count
    end

    test 'should update crop fertilize profile' do
      patch crop_crop_fertilize_profile_path(@crop, @profile), params: {
        crop_fertilize_profile: {
          total_n: 20.0,
          total_p: 6.0,
          total_k: 14.0
        }
      }
      
      assert_redirected_to crop_path(@crop)
      @profile.reload
      assert_equal 20.0, @profile.total_n
    end

    test 'should destroy crop fertilize profile' do
      assert_difference('CropFertilizeProfile.count', -1) do
        delete crop_crop_fertilize_profile_path(@crop, @profile)
      end

      assert_redirected_to crop_path(@crop)
    end

    test 'should handle sources as comma separated string' do
      post crop_crop_fertilize_profiles_path(@crop), params: {
        crop_fertilize_profile: {
          total_n: 18.0,
          total_p: 5.0,
          total_k: 12.0,
          sources: 'source1, source2, source3'
        }
      }

      profile = CropFertilizeProfile.last
      assert_equal ['source1', 'source2', 'source3'], profile.sources
    end

    test 'should not allow access to other users crop' do
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)
      other_profile = create(:crop_fertilize_profile, crop: other_crop)

      get crop_crop_fertilize_profile_path(other_crop, other_profile)
      assert_redirected_to crops_path
    end

    test 'should allow access to reference crop' do
      reference_crop = create(:crop, :tomato, is_reference: true)
      reference_profile = create(:crop_fertilize_profile, crop: reference_crop)

      get crop_crop_fertilize_profile_path(reference_crop, reference_profile)
      assert_response :success
    end

    test 'should render errors on invalid create' do
      assert_no_difference('CropFertilizeProfile.count') do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            total_n: nil,
            total_p: 5.0,
            total_k: 12.0
          }
        }
      end

      assert_response :unprocessable_entity
    end
  end
end

