# frozen_string_literal: true

require 'test_helper'

class Domain::Shared::Policies::PesticidePolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'visible_scope returns a Pesticide relation for a given user' do
    create(:pesticide, is_reference: true, user: nil)
    create(:pesticide, is_reference: false, user: @user)

    scope = Domain::Shared::Policies::PesticidePolicy.visible_scope(Pesticide, @user)

    assert_kind_of ActiveRecord::Relation, scope
    assert_equal Pesticide, scope.klass
  end

  test 'selectable_scope includes reference and user pesticides for regular user' do
    reference_pesticide = create(:pesticide, is_reference: true, user: nil)
    user_pesticide = create(:pesticide, is_reference: false, user: @user)
    other_user_pesticide = create(:pesticide, is_reference: false, user: create(:user))

    scope = Domain::Shared::Policies::PesticidePolicy.selectable_scope(Pesticide, @user)

    assert_includes scope, reference_pesticide
    assert_includes scope, user_pesticide
    assert_not_includes scope, other_user_pesticide
  end

  test 'build_for_create for admin with reference pesticide' do
    pesticide = Domain::Shared::Policies::PesticidePolicy.build_for_create(Pesticide, @admin, name: 'RefPesticide', is_reference: true)

    assert pesticide.is_reference
    assert_nil pesticide.user_id
    assert_equal 'RefPesticide', pesticide.name
  end

  test 'build_for_create for admin with user pesticide (non-reference)' do
    pesticide = Domain::Shared::Policies::PesticidePolicy.build_for_create(Pesticide, @admin, name: 'UserPesticide', is_reference: false)

    assert_not pesticide.is_reference
    assert_equal @admin.id, pesticide.user_id
    assert_equal 'UserPesticide', pesticide.name
  end

  test 'build_for_create for regular user always creates non-reference pesticide owned by user' do
    pesticide = Domain::Shared::Policies::PesticidePolicy.build_for_create(Pesticide, @user, name: 'UserPesticide', is_reference: true)

    assert_not pesticide.is_reference
    assert_equal @user.id, pesticide.user_id
    assert_equal 'UserPesticide', pesticide.name
  end

  test 'find_visible! returns pesticide when it is in visible_scope' do
    pesticide = create(:pesticide, is_reference: false, user: @user)

    assert_equal pesticide, Domain::Shared::Policies::PesticidePolicy.find_visible!(Pesticide, @user, pesticide.id)
  end

  test 'find_visible! raises PolicyPermissionDenied when pesticide is not in visible_scope' do
    other_user_pesticide = create(:pesticide, is_reference: false, user: create(:user))

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::Shared::Policies::PesticidePolicy.find_visible!(Pesticide, @user, other_user_pesticide.id)
    end
  end

  test 'find_editable! delegates to find_visible!' do
    pesticide = create(:pesticide, is_reference: false, user: @user)

    assert_equal pesticide, Domain::Shared::Policies::PesticidePolicy.find_editable!(Pesticide, @user, pesticide.id)
  end

  test 'apply_update! updates is_reference and user_id when reference flag changes' do
    pesticide = create(:pesticide, is_reference: false, user: @user)

    Domain::Shared::Policies::PesticidePolicy.apply_update!(@admin, pesticide, is_reference: true)
    pesticide.reload

    assert pesticide.is_reference
    assert_nil pesticide.user_id

    Domain::Shared::Policies::PesticidePolicy.apply_update!(@admin, pesticide, is_reference: false)
    pesticide.reload

    assert_not pesticide.is_reference
    assert_equal @admin.id, pesticide.user_id
  end

  test 'apply_update! does not touch is_reference when flag is unchanged' do
    pesticide = create(:pesticide, is_reference: false, user: @user)

    Domain::Shared::Policies::PesticidePolicy.apply_update!(@user, pesticide, name: 'UpdatedName', is_reference: false)
    pesticide.reload

    assert_not pesticide.is_reference
    assert_equal @user.id, pesticide.user_id
    assert_equal 'UpdatedName', pesticide.name
  end
end
