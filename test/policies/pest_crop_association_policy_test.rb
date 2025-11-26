# frozen_string_literal: true

require 'test_helper'

class PestCropAssociationPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "accessible_crops_scope for reference pest returns only reference crops" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    reference_crop = create(:crop, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)

    scope = PestCropAssociationPolicy.accessible_crops_scope(reference_pest, user: @user)

    assert_includes scope, reference_crop
    assert_not_includes scope, user_crop
  end

  test "accessible_crops_scope for user pest returns only user's non-reference crops" do
    user_pest = create(:pest, is_reference: false, user: @user)
    reference_crop = create(:crop, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    scope = PestCropAssociationPolicy.accessible_crops_scope(user_pest, user: @user)

    assert_includes scope, user_crop
    assert_not_includes scope, reference_crop
    assert_not_includes scope, other_user_crop
  end

  test "accessible_crops_scope filters by region when pest has region" do
    reference_pest = create(:pest, is_reference: true, user: nil, region: 'jp')
    jp_crop = create(:crop, is_reference: true, user: nil, region: 'jp')
    us_crop = create(:crop, is_reference: true, user: nil, region: 'us')

    scope = PestCropAssociationPolicy.accessible_crops_scope(reference_pest, user: @user)

    assert_includes scope, jp_crop
    assert_not_includes scope, us_crop
  end

  test "crop_accessible_for_pest? returns true for reference pest and reference crop" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    reference_crop = create(:crop, is_reference: true, user: nil)

    assert PestCropAssociationPolicy.crop_accessible_for_pest?(reference_crop, reference_pest, user: @user)
  end

  test "crop_accessible_for_pest? returns false for reference pest and user crop" do
    reference_pest = create(:pest, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)

    assert_not PestCropAssociationPolicy.crop_accessible_for_pest?(user_crop, reference_pest, user: @user)
  end

  test "crop_accessible_for_pest? returns true for user pest and user's crop" do
    user_pest = create(:pest, is_reference: false, user: @user)
    user_crop = create(:crop, is_reference: false, user: @user)

    assert PestCropAssociationPolicy.crop_accessible_for_pest?(user_crop, user_pest, user: @user)
  end

  test "crop_accessible_for_pest? returns false for user pest and other user's crop" do
    user_pest = create(:pest, is_reference: false, user: @user)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    assert_not PestCropAssociationPolicy.crop_accessible_for_pest?(other_user_crop, user_pest, user: @user)
  end

  test "crop_accessible_for_pest? returns false when region mismatch" do
    reference_pest = create(:pest, is_reference: true, user: nil, region: 'jp')
    us_crop = create(:crop, is_reference: true, user: nil, region: 'us')

    assert_not PestCropAssociationPolicy.crop_accessible_for_pest?(us_crop, reference_pest, user: @user)
  end

  test "crop_accessible_for_pest? returns false for user pest and reference crop" do
    user_pest = create(:pest, is_reference: false, user: @user)
    reference_crop = create(:crop, is_reference: true, user: nil)

    assert_not PestCropAssociationPolicy.crop_accessible_for_pest?(reference_crop, user_pest, user: @user)
  end
end
