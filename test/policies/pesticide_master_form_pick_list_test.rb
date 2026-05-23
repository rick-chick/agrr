# frozen_string_literal: true

require "test_helper"

# 農薬マスタフォームの作物・害虫プルダウンは CropPolicy / PestPolicy の index_list_filter 経由。
class PesticideMasterFormPickListTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
    @gateway = Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator,
      crop_gateway: CompositionRoot.crop_gateway,
      pest_gateway: CompositionRoot.pest_gateway
    )
  end

  test "list_crop_pick_rows for admin returns reference and admin's crops" do
    reference_crop = create(:crop, is_reference: true, user: nil)
    admin_crop = create(:crop, is_reference: false, user: @admin)
    other_user_crop = create(:crop, is_reference: false, user: @user)

    rows = @gateway.list_crop_pick_rows_for_pesticide_master_form(
      crop_list_filter: Domain::Shared::Policies::CropPolicy.index_list_filter(@admin)
    )
    ids = rows.map(&:id)

    assert_includes ids, reference_crop.id
    assert_includes ids, admin_crop.id
    assert_not_includes ids, other_user_crop.id
  end

  test "list_crop_pick_rows for regular user returns only user's non-reference crops" do
    reference_crop = create(:crop, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    rows = @gateway.list_crop_pick_rows_for_pesticide_master_form(
      crop_list_filter: Domain::Shared::Policies::CropPolicy.index_list_filter(@user)
    )
    ids = rows.map(&:id)

    assert_not_includes ids, reference_crop.id
    assert_includes ids, user_crop.id
    assert_not_includes ids, other_user_crop.id
  end

  test "list_pest_pick_rows for admin returns reference and admin's pests" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    admin_pest = create(:pest, is_reference: false, user: @admin)
    other_user_pest = create(:pest, is_reference: false, user: @user)

    rows = @gateway.list_pest_pick_rows_for_pesticide_master_form(
      pest_list_filter: Domain::Shared::Policies::PestPolicy.index_list_filter(@admin)
    )
    ids = rows.map(&:id)

    assert_includes ids, reference_pest.id
    assert_includes ids, admin_pest.id
    assert_not_includes ids, other_user_pest.id
  end

  test "list_pest_pick_rows for regular user returns only user's non-reference pests" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    user_pest = create(:pest, is_reference: false, user: @user)
    other_user_pest = create(:pest, is_reference: false, user: create(:user))

    rows = @gateway.list_pest_pick_rows_for_pesticide_master_form(
      pest_list_filter: Domain::Shared::Policies::PestPolicy.index_list_filter(@user)
    )
    ids = rows.map(&:id)

    assert_not_includes ids, reference_pest.id
    assert_includes ids, user_pest.id
    assert_not_includes ids, other_user_pest.id
  end
end
