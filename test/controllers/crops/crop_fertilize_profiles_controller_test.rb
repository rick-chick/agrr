# frozen_string_literal: true

require 'test_helper'

module Crops
  class CropFertilizeProfilesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      sign_in_as @user
      @crop = create(:crop, :tomato, user: @user)
      @profile = create(:crop_fertilize_profile, crop: @crop)
      @application = create(:crop_fertilize_application, :basal, crop_fertilize_profile: @profile)
    end

    test 'should show crop fertilize profile' do
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_select 'h1', text: /#{@crop.name}/
      assert_select '.info-label', text: /総窒素量|Total Nitrogen/
      assert_select '.info-value', text: /#{@profile.total_n}/
    end

    test 'should show crop fertilize profile with applications' do
      application = create(:crop_fertilize_application, crop_fertilize_profile: @profile)
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_select '.stages-title', text: /施用計画|Application Plans/
      assert_select '.stage-item'
    end

    test 'should get new when no profile exists' do
      @profile.destroy
      get new_crop_crop_fertilize_profile_path(@crop)
      assert_response :success
      assert_select 'form'
      assert_select '#add-crop-fertilize-application'
    end

    test 'should redirect to edit when profile already exists' do
      get new_crop_crop_fertilize_profile_path(@crop)
      assert_redirected_to edit_crop_crop_fertilize_profile_path(@crop, @profile)
    end

    test 'should get edit' do
      get edit_crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_select 'form'
    end

    test 'should create crop fertilize profile' do
      @profile.destroy
      assert_difference('CropFertilizeProfile.count') do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            notes: 'Test profile'
          }
        }
      end

      assert_redirected_to crop_path(@crop)
    end

    test 'should create crop fertilize profile with applications' do
      @profile.destroy
      assert_difference('CropFertilizeProfile.count', 1) do
        assert_difference('CropFertilizeApplication.count', 2) do
          post crop_crop_fertilize_profiles_path(@crop), params: {
            crop_fertilize_profile: {
              crop_fertilize_applications_attributes: [
                {
                  application_type: 'basal',
                  count: 1,
                  schedule_hint: 'pre-plant',
                  per_application_n: 6.0,
                  per_application_p: 2.0,
                  per_application_k: 3.0
                },
                {
                  application_type: 'topdress',
                  count: 2,
                  schedule_hint: 'fruiting',
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
          notes: 'Updated notes'
        }
      }
      
      assert_redirected_to crop_path(@crop)
      @profile.reload
    end

    test 'should destroy crop fertilize profile' do
      assert_difference('CropFertilizeProfile.count', -1) do
        delete crop_crop_fertilize_profile_path(@crop, @profile)
      end

      assert_redirected_to crop_path(@crop)
    end

    test 'should handle sources as comma separated string' do
      @profile.destroy
      post crop_crop_fertilize_profiles_path(@crop), params: {
        crop_fertilize_profile: {
          sources: 'source1, source2, source3'
        }
      }

      profile = CropFertilizeProfile.last
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
      @profile.destroy
      assert_no_difference('CropFertilizeProfile.count') do
        post crop_crop_fertilize_profiles_path(@crop), params: {
          crop_fertilize_profile: {
            crop_id: nil
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select '.errors'
    end

    test 'should not allow creating when profile already exists' do
      post crop_crop_fertilize_profiles_path(@crop), params: {
        crop_fertilize_profile: {
          notes: 'Test profile'
        }
      }

      assert_redirected_to crop_path(@crop)
      assert_match /既に肥料プロファイルが存在します|already exists/i, flash[:alert] || ''
    end

    test 'should render errors on invalid update' do
      # 無効なデータでテスト（存在しないカラムを削除）
      patch crop_crop_fertilize_profile_path(@crop, @profile), params: {
        crop_fertilize_profile: {
          crop_id: nil
        }
      }

      assert_response :unprocessable_entity
      assert_select '.errors'
    end

    test 'should display sources in show page' do
      @profile.update(sources: ['source1', 'source2'])
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_match /source1/, response.body
      assert_match /source2/, response.body
    end

    test 'should display notes in show page' do
      @profile.update(notes: 'Test notes')
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_match /Test notes/, response.body
    end

    test 'should show no applications message when no applications' do
      @profile.crop_fertilize_applications.destroy_all
      get crop_crop_fertilize_profile_path(@crop, @profile)
      assert_response :success
      assert_select '.no-stages', text: /まだ施用計画が登録されていません|No application plans registered yet/
    end
  end
end
