# frozen_string_literal: true

require "test_helper"

class PestCropAssociationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user.generate_api_key!
    sign_in_as @user
    @crop1 = create(:crop, user: @user, name: "トマト")
    @crop2 = create(:crop, user: @user, name: "レタス")
    @crop3 = create(:crop, user: @user, name: "ニンジン")
    @reference_crop = create(:crop, :reference, name: "参照作物")
  end

  test "should complete full workflow: create pest with crops, view, edit associations" do
    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 3) do
        post api_v1_masters_pests_path,
             params: {
               pest: {
                 name: "アブラムシ",
                 name_scientific: "Aphidoidea",
                 family: "アブラムシ科",
                 is_reference: false
               },
               crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
             },
             as: :json,
             headers: masters_api_headers
      end
    end

    assert_response :created
    pest = Pest.last
    assert_equal 3, pest.crops.count

    get api_v1_masters_pest_path(pest), headers: masters_api_headers
    assert_response :success

    get api_v1_masters_crop_pests_path(@crop1), headers: masters_api_headers
    assert_response :success
    names = JSON.parse(response.body).map { |p| p["name"] }
    assert_includes names, "アブラムシ"

    crop4 = create(:crop, user: @user, name: "キュウリ")
    assert_difference("CropPest.count", 0) do
      patch api_v1_masters_pest_path(pest),
            params: {
              pest: { name: pest.name },
              crop_ids: [ @crop1.id, @crop2.id, crop4.id ]
            },
            headers: masters_api_headers
    end

    assert_response :success
    pest.reload
    assert_equal 3, pest.crops.count
    assert pest.crops.include?(@crop1)
    assert pest.crops.include?(@crop2)
    assert pest.crops.include?(crop4)
    assert_not pest.crops.include?(@reference_crop)

    other_crop = create(:crop, user: @user)
    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers
    assert_response :success
  end

  test "should handle bidirectional associations correctly" do
    pest1 = create(:pest, is_reference: true, name: "害虫1")
    pest2 = create(:pest, is_reference: true, name: "害虫2")

    assert_difference("CropPest.count", 2) do
      CropPest.create!(crop: @reference_crop, pest: pest1)
      CropPest.create!(crop: @reference_crop, pest: pest2)
    end

    @reference_crop.reload
    assert_equal 2, @reference_crop.pests.count

    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 3) do
        post api_v1_masters_pests_path,
             params: {
               pest: { name: "害虫3", is_reference: false },
               crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
             },
             as: :json,
             headers: masters_api_headers
      end
    end

    pest3 = Pest.last
    assert pest3.crops.include?(@crop1)
    assert pest3.crops.include?(@crop2)
    assert pest3.crops.include?(@reference_crop)

    @crop1.reload
    assert_equal 1, @crop1.pests.count
  end

  test "should maintain data integrity across multiple operations" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    create(:crop_pest, crop: @crop1, pest: pest)
    create(:crop_pest, crop: @crop2, pest: pest)

    patch api_v1_masters_pest_path(pest),
          params: {
            pest: { name: pest.name, description: "更新された説明" },
            crop_ids: [ @crop2.id, @crop3.id ]
          },
          headers: masters_api_headers

    assert_response :success
    pest.reload
    @crop1.reload
    @crop2.reload
    @crop3.reload

    assert_equal 2, pest.crops.count
    assert_not pest.crops.include?(@crop1)
    assert pest.crops.include?(@crop2)
    assert pest.crops.include?(@crop3)

    assert_equal 0, @crop1.pests.count
    assert_equal 1, @crop2.pests.count
    assert_equal 1, @crop3.pests.count
  end

  test "should handle permissions correctly in workflow" do
    other_user = create(:user)
    other_crop = create(:crop, user: other_user)

    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 1) do
        post api_v1_masters_pests_path,
             params: {
               pest: { name: "新しい害虫", is_reference: false },
               crop_ids: [ @crop1.id, other_crop.id ]
             },
             as: :json,
             headers: masters_api_headers
      end
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(@crop1)
    assert_not pest.crops.include?(other_crop)

    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers
    assert_response :not_found
  end

  test "should handle reference crops and pests correctly" do
    reference_pest = create(:pest, is_reference: true, name: "参照害虫")

    assert_difference("CropPest.count", 1) do
      CropPest.create!(crop: @reference_crop, pest: reference_pest)
    end

    @reference_crop.reload
    assert @reference_crop.pests.include?(reference_pest)

    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: reference_pest.id }, headers: masters_api_headers
      assert_response :forbidden
    end

    @crop1.reload
    assert_not @crop1.pests.include?(reference_pest)
    reference_pest.reload
    assert_equal 1, reference_pest.crops.count
  end

  test "should prevent duplicate associations in workflow" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    assert_difference("CropPest.count", 1) do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: pest.id }, headers: masters_api_headers
      assert_response :created
    end

    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: pest.id }, headers: masters_api_headers
      assert_response :unprocessable_entity
    end

    json = JSON.parse(response.body)
    assert_equal I18n.t("api.errors.pests.already_associated"), json["error"]

    @crop1.reload
    assert_equal 1, @crop1.pests.where(id: pest.id).count
  end

  test "should handle large number of associations" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")
    crops = 10.times.map { create(:crop, user: @user) }

    assert_difference("CropPest.count", 10) do
      patch api_v1_masters_pest_path(pest),
            params: { pest: { name: pest.name }, crop_ids: crops.map(&:id) },
            headers: masters_api_headers
    end

    assert_response :success
    pest.reload
    assert_equal 10, pest.crops.count
  end

  test "should handle empty associations correctly" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    assert_equal 0, pest.crops.count

    create(:crop_pest, crop: @crop1, pest: pest)
    pest.reload
    assert_equal 1, pest.crops.count

    patch api_v1_masters_pest_path(pest),
          params: { pest: { name: pest.name }, crop_ids: [] },
          headers: masters_api_headers

    assert_response :success
    pest.reload
    assert_equal 0, pest.crops.count
  end

  test "should handle concurrent association updates" do
    pest1 = create(:pest, is_reference: true, name: "害虫1")
    pest2 = create(:pest, is_reference: true, name: "害虫2")

    assert_difference("CropPest.count", 2) do
      CropPest.create!(crop: @reference_crop, pest: pest1)
      CropPest.create!(crop: @reference_crop, pest: pest2)
    end

    @reference_crop.reload
    assert_equal 2, @reference_crop.pests.count

    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 3) do
        post api_v1_masters_pests_path,
             params: {
               pest: { name: "害虫3", is_reference: false },
               crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
             },
             as: :json,
             headers: masters_api_headers
      end
    end

    pest3 = Pest.last
    assert pest3.crops.include?(@crop1)
    assert pest3.crops.include?(@crop2)
    assert pest3.crops.include?(@reference_crop)

    @reference_crop.reload
    assert_equal 3, @reference_crop.pests.count
  end

  test "should handle error cases gracefully" do
    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: 99999 }, headers: masters_api_headers
      assert_response :not_found
    end

    assert_difference("CropPest.count", 1) do
      post api_v1_masters_pests_path,
           params: {
             pest: { name: "新しい害虫", is_reference: false },
             crop_ids: [ @crop1.id, 99999 ]
           },
           as: :json,
           headers: masters_api_headers
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(@crop1)
  end

  test "admin should not see other user's pests" do
    admin_user = create(:user, admin: true)
    admin_user.generate_api_key!
    sign_in_as admin_user

    admin_crop = create(:crop, user: admin_user)
    admin_pest = create(:pest, :user_owned, user: admin_user, name: "管理者害虫B")
    reference_pest = create(:pest, is_reference: true, user_id: nil, name: "参照害虫A")
    other_user = create(:user)
    other_crop = create(:crop, user: other_user)
    other_user_pest = create(:pest, :user_owned, user: other_user, name: "他人害虫C")

    get api_v1_masters_pests_path, headers: masters_api_headers(admin_user)
    assert_response :success
    names = JSON.parse(response.body).map { |p| p["name"] }
    assert_includes names, reference_pest.name
    assert_includes names, admin_pest.name
    assert_not_includes names, other_user_pest.name

    get api_v1_masters_pest_path(other_user_pest), headers: masters_api_headers(admin_user)
    assert_response :forbidden

    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers(admin_user)
    assert_response :success
    assert_equal [], JSON.parse(response.body)

    create(:crop_pest, crop: admin_crop, pest: reference_pest)
    create(:crop_pest, crop: admin_crop, pest: admin_pest)
    create(:crop_pest, crop: admin_crop, pest: other_user_pest)

    get api_v1_masters_crop_pests_path(admin_crop), headers: masters_api_headers(admin_user)
    assert_response :success
    crop_pest_names = JSON.parse(response.body).map { |p| p["name"] }
    assert_includes crop_pest_names, reference_pest.name
    assert_includes crop_pest_names, admin_pest.name
    assert_not_includes crop_pest_names, other_user_pest.name
  end

  test "admin should access reference pests and own pests" do
    admin_user = create(:user, admin: true)
    admin_user.generate_api_key!
    sign_in_as admin_user

    admin_pest = create(:pest, :user_owned, user: admin_user)
    reference_pest = create(:pest, is_reference: true, user_id: nil)

    get api_v1_masters_pest_path(reference_pest), headers: masters_api_headers(admin_user)
    assert_response :success

    get api_v1_masters_pest_path(admin_pest), headers: masters_api_headers(admin_user)
    assert_response :success
  end

  private

  def masters_api_headers(for_user = @user)
    for_user.generate_api_key! unless for_user.api_key.present?
    { "Accept" => "application/json", "X-API-Key" => for_user.api_key }
  end
end
