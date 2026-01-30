# frozen_string_literal: true

require 'test_helper'

class Domain::Shared::Policies::FarmPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'visible_scope returns reference farms and user owned farms for user' do
    reference_farm = create(:farm, :reference)
    user_farm = create(:farm, is_reference: false, user: @user)
    other_user_farm = create(:farm, is_reference: false, user: create(:user))

    scope = Domain::Shared::Policies::FarmPolicy.visible_scope(Farm, @user)

    assert_includes scope, reference_farm
    assert_includes scope, user_farm
    assert_not_includes scope, other_user_farm
  end

  test 'visible_scope returns all farms for admin' do
    reference_farm = create(:farm, :reference)
    user_farm = create(:farm, is_reference: false, user: @user)
    other_user_farm = create(:farm, is_reference: false, user: create(:user))

    scope = Domain::Shared::Policies::FarmPolicy.visible_scope(Farm, @admin)

    assert_includes scope, reference_farm
    assert_includes scope, user_farm
    assert_includes scope, other_user_farm
  end

  test 'user_owned_scope returns only non-reference farms owned by given user' do
    reference_farm = create(:farm, :reference)
    user_farm = create(:farm, user: @user)
    other_user_farm = create(:farm, user: create(:user))

    scope = Domain::Shared::Policies::FarmPolicy.user_owned_scope(Farm, @user)

    assert_includes scope, user_farm
    assert_not_includes scope, reference_farm
    assert_not_includes scope, other_user_farm
  end

  test 'build_for_create always creates non-reference farm owned by user' do
    farm = Domain::Shared::Policies::FarmPolicy.build_for_create(Farm, @user, {
      name: 'TestFarm',
      region: 'jp',
      latitude: 35.0,
      longitude: 135.0
    })

    assert_not farm.is_reference
    assert_equal @user.id, farm.user_id
    assert_equal 'TestFarm', farm.name
    assert_equal 'jp', farm.region
    assert_equal 35.0, farm.latitude
    assert_equal 135.0, farm.longitude
  end

  test 'find_visible! allows admin to see any farm' do
    other_user = create(:user)
    farm = create(:farm, is_reference: false, user: other_user)

    assert_equal farm, Domain::Shared::Policies::FarmPolicy.find_visible!(Farm, @admin, farm.id)
  end

  test 'find_visible! allows user to see reference and own farms' do
    reference_farm = create(:farm, :reference)
    own_farm = create(:farm, is_reference: false, user: @user)

    assert_equal reference_farm, Domain::Shared::Policies::FarmPolicy.find_visible!(Farm, @user, reference_farm.id)
    assert_equal own_farm, Domain::Shared::Policies::FarmPolicy.find_visible!(Farm, @user, own_farm.id)
  end

  test 'find_visible! raises PolicyPermissionDenied for other user non-reference farm' do
    other_user_farm = create(:farm, is_reference: false, user: create(:user))

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FarmPolicy.find_visible!(Farm, @user, other_user_farm.id)
    end
  end

  test 'find_owned! allows admin to see any farm' do
    other_user = create(:user)
    farm = create(:farm, is_reference: false, user: other_user)

    assert_equal farm, Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, @admin, farm.id)
  end

  test 'find_owned! allows user to see only own non-reference farms' do
    own_farm = create(:farm, is_reference: false, user: @user)

    assert_equal own_farm, Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, @user, own_farm.id)
  end

  test 'find_owned! raises PolicyPermissionDenied for reference or other user farm' do
    reference_farm = create(:farm, :reference)
    other_user_farm = create(:farm, is_reference: false, user: create(:user))

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, @user, reference_farm.id)
    end

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FarmPolicy.find_owned!(Farm, @user, other_user_farm.id)
    end
  end

  test 'find_editable! allows admin to edit any farm' do
    other_user = create(:user)
    farm = create(:farm, is_reference: false, user: other_user)

    assert_equal farm, Domain::Shared::Policies::FarmPolicy.find_editable!(Farm, @admin, farm.id)
  end

  test 'find_editable! allows user to edit only own non-reference farms' do
    own_farm = create(:farm, is_reference: false, user: @user)

    assert_equal own_farm, Domain::Shared::Policies::FarmPolicy.find_editable!(Farm, @user, own_farm.id)
  end

  test 'find_editable! raises PolicyPermissionDenied for reference or other user farm' do
    reference_farm = create(:farm, :reference)
    other_user_farm = create(:farm, is_reference: false, user: create(:user))

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FarmPolicy.find_editable!(Farm, @user, reference_farm.id)
    end

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FarmPolicy.find_editable!(Farm, @user, other_user_farm.id)
    end
  end

  test 'apply_update! updates farm attributes' do
    farm = create(:farm, name: 'OldName', region: 'jp', user: @user)

    Domain::Shared::Policies::FarmPolicy.apply_update!(@user, farm, name: 'NewName', region: 'us')
    farm.reload

    assert_equal 'NewName', farm.name
    assert_equal 'us', farm.region
  end

  test 'reference_scope returns only reference farms and filters by region when given' do
    jp_reference = create(:farm, :reference, region: 'jp')
    us_reference = create(:farm, :reference, region: 'us')
    user_farm = create(:farm, is_reference: false, user: @user, region: 'jp')

    all_reference = Domain::Shared::Policies::FarmPolicy.reference_scope(Farm)
    jp_only = Domain::Shared::Policies::FarmPolicy.reference_scope(Farm, region: 'jp')

    assert_includes all_reference, jp_reference
    assert_includes all_reference, us_reference
    assert_not_includes all_reference, user_farm

    assert_includes jp_only, jp_reference
    assert_not_includes jp_only, us_reference
  end
end