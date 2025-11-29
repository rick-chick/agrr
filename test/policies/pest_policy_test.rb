# frozen_string_literal: true

require 'test_helper'

class PestPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'visible_scope uses ReferencableResourcePolicy.visible_scope_for' do
    reference_pest = create(:pest, is_reference: true, user: nil)
    admin_pest = create(:pest, is_reference: false, user: @admin)
    user_pest = create(:pest, is_reference: false, user: @user)

    scope_for_user = PestPolicy.visible_scope(@user)
    scope_for_admin = PestPolicy.visible_scope(@admin)

    # 一般ユーザー: 自分の非参照害虫のみ
    assert_includes scope_for_user, user_pest
    assert_not_includes scope_for_user, reference_pest
    assert_not_includes scope_for_user, admin_pest

    # 管理者: 参照害虫 + 自分の害虫
    assert_includes scope_for_admin, reference_pest
    assert_includes scope_for_admin, admin_pest
    assert_not_includes scope_for_admin, user_pest
  end

  test 'selectable_scope includes reference and user pests for regular user' do
    reference_pest = create(:pest, is_reference: true, user: nil)
    user_pest = create(:pest, is_reference: false, user: @user)
    other_user_pest = create(:pest, is_reference: false, user: create(:user))

    scope = PestPolicy.selectable_scope(@user)

    assert_includes scope, reference_pest
    assert_includes scope, user_pest
    assert_not_includes scope, other_user_pest
  end

  test 'build_for_create for admin with reference pest' do
    pest = PestPolicy.build_for_create(@admin, { name: 'RefPest', is_reference: true })

    assert pest.is_reference
    assert_nil pest.user_id
    assert_equal 'RefPest', pest.name
  end

  test 'build_for_create for admin with user pest (non-reference)' do
    pest = PestPolicy.build_for_create(@admin, { name: 'UserPest', is_reference: false })

    assert_not pest.is_reference
    assert_equal @admin.id, pest.user_id
    assert_equal 'UserPest', pest.name
  end

  test 'build_for_create for regular user always creates non-reference pest owned by user' do
    pest = PestPolicy.build_for_create(@user, { name: 'UserPest', is_reference: true })

    assert_not pest.is_reference
    assert_equal @user.id, pest.user_id
    assert_equal 'UserPest', pest.name
  end

  test 'build_for_create with admin_forced behaves like admin even for regular user' do
    pest = PestPolicy.build_for_create(@user, { name: 'RefPest', is_reference: true }, admin_forced: true)

    assert pest.is_reference
    assert_nil pest.user_id
  end

  test 'find_visible! allows access to reference pest and own pest' do
    reference_pest = create(:pest, is_reference: true, user: nil)
    own_pest = create(:pest, is_reference: false, user: @user)

    assert_equal reference_pest, PestPolicy.find_visible!(@user, reference_pest.id)
    assert_equal own_pest, PestPolicy.find_visible!(@user, own_pest.id)
  end

  test 'find_visible! raises PolicyPermissionDenied for other users non-reference pest' do
    other_pest = create(:pest, is_reference: false, user: create(:user))

    assert_raises(PolicyPermissionDenied) do
      PestPolicy.find_visible!(@user, other_pest.id)
    end
  end

  test 'find_editable! rules for admin and regular user' do
    reference_pest = create(:pest, is_reference: true, user: nil)
    admin_pest = create(:pest, is_reference: false, user: @admin)
    user_pest = create(:pest, is_reference: false, user: @user)

    # 管理者: 参照害虫 + 自分の害虫は編集可能
    assert_equal reference_pest, PestPolicy.find_editable!(@admin, reference_pest.id)
    assert_equal admin_pest, PestPolicy.find_editable!(@admin, admin_pest.id)

    # 一般ユーザー: 自分の非参照害虫のみ編集可能
    assert_equal user_pest, PestPolicy.find_editable!(@user, user_pest.id)

    # 一般ユーザーは参照害虫を編集不可
    assert_raises(PolicyPermissionDenied) do
      PestPolicy.find_editable!(@user, reference_pest.id)
    end
  end

  test 'apply_update! updates is_reference and user_id when reference flag changes' do
    pest = create(:pest, is_reference: false, user: @user)

    PestPolicy.apply_update!(@admin, pest, { is_reference: true })
    pest.reload

    assert pest.is_reference
    assert_nil pest.user_id

    PestPolicy.apply_update!(@admin, pest, { is_reference: false })
    pest.reload

    assert_not pest.is_reference
    assert_equal @admin.id, pest.user_id
  end

  test 'apply_update! leaves user_id as-is when reference flag not present' do
    pest = create(:pest, is_reference: false, user: @user)

    PestPolicy.apply_update!(@user, pest, { name: 'UpdatedName' })
    pest.reload

    assert_not pest.is_reference
    assert_equal @user.id, pest.user_id
    assert_equal 'UpdatedName', pest.name
  end
end
