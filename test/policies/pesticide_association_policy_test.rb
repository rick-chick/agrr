# frozen_string_literal: true

require "test_helper"

# PesticideAssociationAccess は削除され、ロジックはアダプターの gateway メソッドへ移管された。
# このテストはアダプターの実装を直接検証する。
class PesticideAssociationAccessTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
    @gateway = Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
  end

  test "accessible_crops_scope for admin returns reference and admin's crops" do
    reference_crop = create(:crop, is_reference: true, user: nil)
    admin_crop = create(:crop, is_reference: false, user: @admin)
    other_user_crop = create(:crop, is_reference: false, user: @user)

    scope = @gateway.accessible_crops_scope_for_pesticide_master_form(user: @admin)

    assert_includes scope, reference_crop
    assert_includes scope, admin_crop
    assert_not_includes scope, other_user_crop
  end

  test "accessible_crops_scope for regular user returns only user's non-reference crops" do
    reference_crop = create(:crop, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    scope = @gateway.accessible_crops_scope_for_pesticide_master_form(user: @user)

    assert_not_includes scope, reference_crop
    assert_includes scope, user_crop
    assert_not_includes scope, other_user_crop
  end

  test "accessible_pests_scope for admin returns reference and admin's pests" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    admin_pest = create(:pest, is_reference: false, user: @admin)
    other_user_pest = create(:pest, is_reference: false, user: @user)

    scope = @gateway.accessible_pests_scope_for_pesticide_master_form(user: @admin)

    assert_includes scope, reference_pest
    assert_includes scope, admin_pest
    assert_not_includes scope, other_user_pest
  end

  test "accessible_pests_scope for regular user returns only user's non-reference pests" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    user_pest = create(:pest, is_reference: false, user: @user)
    other_user_pest = create(:pest, is_reference: false, user: create(:user))

    scope = @gateway.accessible_pests_scope_for_pesticide_master_form(user: @user)

    assert_not_includes scope, reference_pest
    assert_includes scope, user_pest
    assert_not_includes scope, other_user_pest
  end
end
