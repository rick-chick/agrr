# frozen_string_literal: true

require 'test_helper'

class Domain::Shared::Policies::FertilizePolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'build_for_create for admin with reference fertilize' do
    fertilize = Domain::Shared::Policies::FertilizePolicy.build_for_create(Fertilize, @admin, name: 'RefFertilize', is_reference: true)

    assert fertilize.is_reference
    assert_nil fertilize.user_id
    assert_equal 'RefFertilize', fertilize.name
  end

  test 'build_for_create for admin with user fertilize (non-reference)' do
    fertilize = Domain::Shared::Policies::FertilizePolicy.build_for_create(Fertilize, @admin, name: 'UserFertilize', is_reference: false)

    assert_not fertilize.is_reference
    assert_equal @admin.id, fertilize.user_id
    assert_equal 'UserFertilize', fertilize.name
  end

  test 'build_for_create for regular user always creates non-reference fertilize owned by user' do
    fertilize = Domain::Shared::Policies::FertilizePolicy.build_for_create(Fertilize, @user, name: 'UserFertilize', is_reference: true)

    assert_not fertilize.is_reference
    assert_equal @user.id, fertilize.user_id
    assert_equal 'UserFertilize', fertilize.name
  end

  test 'find_visible! returns fertilize when it is in visible_scope' do
    fertilize = create(:fertilize, is_reference: false, user: @user)

    assert_equal fertilize, Domain::Shared::Policies::FertilizePolicy.find_visible!(Fertilize, @user, fertilize.id)
  end

  test 'find_visible! raises PolicyPermissionDenied when fertilize is not in visible_scope' do
    other_user_fertilize = create(:fertilize, is_reference: false, user: create(:user))

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::FertilizePolicy.find_visible!(Fertilize, @user, other_user_fertilize.id)
    end
  end

  test 'find_editable! delegates to find_visible!' do
    fertilize = create(:fertilize, is_reference: false, user: @user)

    assert_equal fertilize, Domain::Shared::Policies::FertilizePolicy.find_editable!(Fertilize, @user, fertilize.id)
  end

  test 'apply_update! updates is_reference and user_id when reference flag changes' do
    fertilize = create(:fertilize, is_reference: false, user: @user)

    Domain::Shared::Policies::FertilizePolicy.apply_update!(@admin, fertilize, is_reference: true)
    fertilize.reload

    assert fertilize.is_reference
    assert_nil fertilize.user_id

    Domain::Shared::Policies::FertilizePolicy.apply_update!(@admin, fertilize, is_reference: false)
    fertilize.reload

    assert_not fertilize.is_reference
    assert_equal @admin.id, fertilize.user_id
  end

  test 'apply_update! does not touch is_reference when flag is unchanged' do
    fertilize = create(:fertilize, is_reference: false, user: @user)

    Domain::Shared::Policies::FertilizePolicy.apply_update!(@user, fertilize, name: 'UpdatedName', is_reference: false)
    fertilize.reload

    assert_not fertilize.is_reference
    assert_equal @user.id, fertilize.user_id
    assert_equal 'UpdatedName', fertilize.name
  end
end
