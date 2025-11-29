# frozen_string_literal: true

require 'test_helper'

class CropPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'user_owned_non_reference_scope returns only non-reference crops owned by given user' do
    reference_crop = create(:crop, is_reference: true, user: nil)
    user_crop = create(:crop, is_reference: false, user: @user)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    scope = CropPolicy.user_owned_non_reference_scope(@user)

    assert_includes scope, user_crop
    assert_not_includes scope, reference_crop
    assert_not_includes scope, other_user_crop
  end

  test 'build_for_create for admin with reference crop' do
    crop = CropPolicy.build_for_create(@admin, name: 'RefCrop', is_reference: true)

    assert crop.is_reference
    assert_nil crop.user_id
    assert_equal 'RefCrop', crop.name
  end

  test 'build_for_create for admin with user crop (non-reference)' do
    crop = CropPolicy.build_for_create(@admin, name: 'UserCrop', is_reference: false)

    assert_not crop.is_reference
    assert_equal @admin.id, crop.user_id
    assert_equal 'UserCrop', crop.name
  end

  test 'build_for_create for regular user always creates non-reference crop owned by user' do
    crop = CropPolicy.build_for_create(@user, name: 'UserCrop', is_reference: true)

    assert_not crop.is_reference
    assert_equal @user.id, crop.user_id
    assert_equal 'UserCrop', crop.name
  end

  test 'find_visible! allows admin to see any crop' do
    other_user = create(:user)
    crop = create(:crop, is_reference: false, user: other_user)

    assert_equal crop, CropPolicy.find_visible!(@admin, crop.id)
  end

  test 'find_visible! allows user to see reference and own crops' do
    reference_crop = create(:crop, is_reference: true, user: nil)
    own_crop = create(:crop, is_reference: false, user: @user)

    assert_equal reference_crop, CropPolicy.find_visible!(@user, reference_crop.id)
    assert_equal own_crop, CropPolicy.find_visible!(@user, own_crop.id)
  end

  test 'find_visible! raises PolicyPermissionDenied for other user non-reference crop' do
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    assert_raises(PolicyPermissionDenied) do
      CropPolicy.find_visible!(@user, other_user_crop.id)
    end
  end

  test 'find_editable! allows admin to edit any crop' do
    other_user = create(:user)
    crop = create(:crop, is_reference: false, user: other_user)

    assert_equal crop, CropPolicy.find_editable!(@admin, crop.id)
  end

  test 'find_editable! allows user to edit only own non-reference crops' do
    own_crop = create(:crop, is_reference: false, user: @user)

    assert_equal own_crop, CropPolicy.find_editable!(@user, own_crop.id)
  end

  test 'find_editable! raises PolicyPermissionDenied for reference or other user crop' do
    reference_crop = create(:crop, is_reference: true, user: nil)
    other_user_crop = create(:crop, is_reference: false, user: create(:user))

    assert_raises(PolicyPermissionDenied) do
      CropPolicy.find_editable!(@user, reference_crop.id)
    end

    assert_raises(PolicyPermissionDenied) do
      CropPolicy.find_editable!(@user, other_user_crop.id)
    end
  end

  test 'apply_update! updates is_reference and user_id when reference flag changes' do
    crop = create(:crop, is_reference: false, user: @user)

    CropPolicy.apply_update!(@admin, crop, is_reference: true)
    crop.reload

    assert crop.is_reference
    assert_nil crop.user_id

    CropPolicy.apply_update!(@admin, crop, is_reference: false)
    crop.reload

    assert_not crop.is_reference
    assert_equal @admin.id, crop.user_id
  end

  test 'apply_update! does not touch is_reference when flag is unchanged' do
    crop = create(:crop, is_reference: false, user: @user)

    CropPolicy.apply_update!(@user, crop, name: 'UpdatedName', is_reference: false)
    crop.reload

    assert_not crop.is_reference
    assert_equal @user.id, crop.user_id
    assert_equal 'UpdatedName', crop.name
  end

  test 'reference_scope returns only reference crops and filters by region when given' do
    jp_reference = create(:crop, is_reference: true, user: nil, region: 'jp')
    us_reference = create(:crop, is_reference: true, user: nil, region: 'us')
    user_crop = create(:crop, is_reference: false, user: @user, region: 'jp')

    all_reference = CropPolicy.reference_scope
    jp_only = CropPolicy.reference_scope(region: 'jp')

    assert_includes all_reference, jp_reference
    assert_includes all_reference, us_reference
    assert_not_includes all_reference, user_crop

    assert_includes jp_only, jp_reference
    assert_not_includes jp_only, us_reference
  end
end
