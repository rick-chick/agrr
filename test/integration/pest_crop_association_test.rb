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

  # ========== エンドツーエンドシナリオ ==========

  test "should complete full workflow: create pest with crops, view, edit associations" do
    # 1. 害虫を作成して複数の作物と関連付け（ユーザー害虫は参照作物も含めて紐づけ可能）
    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 3) do
        post pests_path, params: {
          pest: {
            name: "アブラムシ",
            name_scientific: "Aphidoidea",
            family: "アブラムシ科",
            is_reference: false
          },
          crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
        }
      end
    end

    pest = Pest.last
    assert_redirected_to pest_path(pest)
    assert_equal 3, pest.crops.count

    # 2. 害虫詳細画面で作物一覧を確認
    get pest_path(pest)
    assert_response :success
    assert_select ".related-crop-card", count: 3

    # 3. 作物詳細画面で害虫一覧を確認
    get crop_path(@crop1)
    assert_response :success
    assert_select "a.pest-card__link", text: "アブラムシ"

    # 4. 害虫の関連付けを編集（参照作物を削除、crop4を追加 → net 0）
    crop4 = create(:crop, user: @user, name: "キュウリ")
    assert_difference("CropPest.count", 0) do  # 参照作物削除(-1) + crop4追加(+1) = 0
      patch pest_path(pest), params: {
        pest: {
          name: pest.name
        },
        crop_ids: [ @crop1.id, @crop2.id, crop4.id ]  # crop4を追加、参照作物を削除
      }
    end

    pest.reload
    assert_equal 3, pest.crops.count
    assert pest.crops.include?(@crop1)
    assert pest.crops.include?(@crop2)
    assert pest.crops.include?(crop4)
    assert_not pest.crops.include?(@reference_crop)

    # 5. 作物単位の害虫管理画面から害虫を削除
    other_crop = create(:crop, user: @user)
    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers
    assert_response :success
  end

  test "should handle bidirectional associations correctly" do
    # 作物から害虫を関連付け
    pest1 = create(:pest, is_reference: true, name: "害虫1")
    pest2 = create(:pest, is_reference: true, name: "害虫2")

    # 参照作物に参照害虫を関連付け（参照害虫は参照作物のみ）
    assert_difference("CropPest.count", 2) do
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest1.id }, headers: masters_api_headers
      assert_response :created
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest2.id }, headers: masters_api_headers
      assert_response :created
    end

    @reference_crop.reload
    assert_equal 2, @reference_crop.pests.count

    # 害虫管理画面から同じ作物を選択して新規害虫を作成
    assert_difference("Pest.count", 1) do
      assert_difference("CropPest.count", 3) do  # ユーザー害虫は参照作物も含めて紐づけ可能
        post pests_path, params: {
          pest: {
            name: "害虫3",
            is_reference: false
          },
          crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
        }
      end
    end

    pest3 = Pest.last
    assert pest3.crops.include?(@crop1)
    assert pest3.crops.include?(@crop2)
    assert pest3.crops.include?(@reference_crop)

    # @crop1には1つの害虫が関連付けられている
    @crop1.reload
    assert_equal 1, @crop1.pests.count
  end

  test "should maintain data integrity across multiple operations" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    # 1. 最初に関連付け
    create(:crop_pest, crop: @crop1, pest: pest)
    create(:crop_pest, crop: @crop2, pest: pest)

    # 2. 害虫編集画面から関連付けを更新
    patch pest_path(pest), params: {
      pest: {
        name: pest.name,
        description: "更新された説明"
      },
      crop_ids: [ @crop2.id, @crop3.id ]  # @crop1を削除、@crop3を追加
    }

    pest.reload
    @crop1.reload
    @crop2.reload
    @crop3.reload

    # 関連付けの整合性を確認
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

    # 他人の作物は関連付けできない
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")
    assert_difference("CropPest.count", 1) do  # @crop1のみ
      post pests_path, params: {
        pest: {
          name: "新しい害虫",
          is_reference: false
        },
        crop_ids: [ @crop1.id, other_crop.id ]
      }
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(@crop1)
    assert_not pest.crops.include?(other_crop)

    # 他人の作物の害虫管理画面にはアクセスできない
    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers
    assert_response :forbidden
  end

  test "should handle reference crops and pests correctly" do
    reference_pest = create(:pest, is_reference: true, name: "参照害虫")

    # 参照害虫を参照作物に関連付け（一般ユーザーでも可能）
    assert_difference("CropPest.count", 1) do
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: reference_pest.id }, headers: masters_api_headers
      assert_response :created
    end

    @reference_crop.reload
    assert @reference_crop.pests.include?(reference_pest)

    # 参照害虫は参照作物にしか紐づけできない → 自分の作物には関連付け不可
    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: reference_pest.id }, headers: masters_api_headers
      assert_response :forbidden
    end

    @crop1.reload
    assert_not @crop1.pests.include?(reference_pest)
    reference_pest.reload
    assert_equal 1, reference_pest.crops.count  # 参照作物のみ
  end

  test "should prevent duplicate associations in workflow" do
    pest = create(:pest, is_reference: true, name: "テスト害虫")

    # 参照害虫は参照作物にしか紐づけできない
    assert_difference("CropPest.count", 1) do
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest.id }, headers: masters_api_headers
      assert_response :created
    end

    # 同じ害虫を同じ作物に関連付けようとする（2回目 - 重複）
    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest.id }, headers: masters_api_headers
      assert_response :unprocessable_entity
    end

    json = JSON.parse(response.body)
    assert_equal I18n.t("api.errors.pests.already_associated"), json["error"]

    @reference_crop.reload
    assert_equal 1, @reference_crop.pests.count  # 重複しない
  end

  test "should handle large number of associations" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    # 10個の作物を作成
    crops = 10.times.map { create(:crop, user: @user) }

    # すべての作物を関連付け
    assert_difference("CropPest.count", 10) do
      patch pest_path(pest), params: {
        pest: {
          name: pest.name
        },
        crop_ids: crops.map(&:id)
      }
    end

    pest.reload
    assert_equal 10, pest.crops.count

    # 詳細画面で表示されることを確認
    get pest_path(pest)
    assert_response :success
    assert_select ".related-crop-card", count: 10
  end

  test "should handle empty associations correctly" do
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

    # 初期状態では関連付けなし
    get pest_path(pest)
    assert_response :success
    assert_select ".no-crops"

    # 作物を追加
    create(:crop_pest, crop: @crop1, pest: pest)

    get pest_path(pest)
    assert_response :success
    assert_select ".related-crop-card", count: 1

    # すべての関連付けを削除
    patch pest_path(pest), params: {
      pest: {
        name: pest.name
      },
      crop_ids: []
    }

    pest.reload
    assert_equal 0, pest.crops.count

    get pest_path(pest)
    assert_response :success
    assert_select ".no-crops"
  end

  test "should handle concurrent association updates" do
    pest1 = create(:pest, is_reference: true, name: "害虫1")
    pest2 = create(:pest, is_reference: true, name: "害虫2")

    # 同じ参照作物に2つの害虫を同時に関連付け（順次実行）
    assert_difference("CropPest.count", 2) do
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest1.id }, headers: masters_api_headers
      assert_response :created
      post api_v1_masters_crop_pests_path(@reference_crop), params: { pest_id: pest2.id }, headers: masters_api_headers
      assert_response :created
    end

    @reference_crop.reload
    assert_equal 2, @reference_crop.pests.count
    assert @reference_crop.pests.include?(pest1)
    assert @reference_crop.pests.include?(pest2)

    # 2つの害虫に同じ作物を関連付け
    assert_difference("CropPest.count", 3) do  # ユーザー害虫は参照作物も含めて紐づけ可能
      post pests_path, params: {
        pest: {
          name: "害虫3",
          is_reference: false
        },
        crop_ids: [ @crop1.id, @crop2.id, @reference_crop.id ]
      }
    end

    pest3 = Pest.last
    assert pest3.crops.include?(@crop1)
    assert pest3.crops.include?(@crop2)
    assert pest3.crops.include?(@reference_crop)

    @reference_crop.reload
    assert_equal 3, @reference_crop.pests.count  # 3つの害虫に関連付けられている
  end

  test "should handle error cases gracefully" do
    # 存在しない害虫IDで関連付け試行
    assert_no_difference("CropPest.count") do
      post api_v1_masters_crop_pests_path(@crop1), params: { pest_id: 99999 }, headers: masters_api_headers
      assert_response :not_found
    end

    # 存在しない作物IDを含む選択
    pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")
    assert_difference("CropPest.count", 1) do  # @crop1のみ
      post pests_path, params: {
        pest: {
          name: "新しい害虫",
          is_reference: false
        },
        crop_ids: [ @crop1.id, 99999 ]
      }
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

    # 管理者の害虫一覧には参照害虫と自分の害虫のみ表示される
    get pests_path
    assert_response :success
    assert_select ".crop-card .crop-name", text: reference_pest.name, count: 1
    assert_select ".crop-card .crop-name", text: admin_pest.name, count: 1
    assert_select ".crop-card .crop-name", text: other_user_pest.name, count: 0

    # 管理者は他人の害虫の詳細にアクセスできない
    get pest_path(other_user_pest)
    assert_redirected_to pests_path
    assert_equal I18n.t("pests.flash.no_permission"), flash[:alert]

    # 管理者は他人の作物の害虫一覧 API にアクセスできない
    get api_v1_masters_crop_pests_path(other_crop), headers: masters_api_headers(admin_user)
    assert_response :forbidden

    # 管理者の作物の害虫一覧 API には参照害虫と自分の害虫のみ含まれる
    create(:crop_pest, crop: admin_crop, pest: reference_pest)
    create(:crop_pest, crop: admin_crop, pest: admin_pest)
    create(:crop_pest, crop: admin_crop, pest: other_user_pest)

    get api_v1_masters_crop_pests_path(admin_crop), headers: masters_api_headers(admin_user)
    assert_response :success
    names = JSON.parse(response.body).map { |p| p["name"] }
    assert_includes names, reference_pest.name
    assert_includes names, admin_pest.name
    assert_not_includes names, other_user_pest.name
  end

  test "admin should access reference pests and own pests" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    admin_crop = create(:crop, user: admin_user)
    admin_pest = create(:pest, :user_owned, user: admin_user)
    reference_pest = create(:pest, is_reference: true, user_id: nil)

    # 管理者は参照害虫にアクセス可能
    get pest_path(reference_pest)
    assert_response :success

    get edit_pest_path(reference_pest)
    assert_response :success

    # 管理者は自分の害虫にアクセス可能
    get pest_path(admin_pest)
    assert_response :success

    get edit_pest_path(admin_pest)
    assert_response :success

    # 管理者の作物からも参照害虫と自分の害虫の詳細 HTML にアクセス可能
    create(:crop_pest, crop: admin_crop, pest: reference_pest)
    create(:crop_pest, crop: admin_crop, pest: admin_pest)

    get pest_path(reference_pest, locale: :us)
    assert_response :success

    get pest_path(admin_pest, locale: :us)
    assert_response :success
  end

  private

  def masters_api_headers(for_user = @user)
    for_user.generate_api_key! unless for_user.api_key.present?
    { "Accept" => "application/json", "X-API-Key" => for_user.api_key }
  end
end
