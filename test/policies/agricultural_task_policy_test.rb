# frozen_string_literal: true

require 'test_helper'

class Domain::Shared::Policies::AgriculturalTaskPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test 'visible_scope delegates to visible_scope_for and respects admin/user rules' do
    reference_task = create(:agricultural_task) # デフォルトは参照タスク想定
    admin_task = create(:agricultural_task, :user_owned, user: @admin)
    user_task = create(:agricultural_task, :user_owned, user: @user)

    scope_for_user = Domain::Shared::Policies::AgriculturalTaskPolicy.visible_scope(AgriculturalTask, @user)
    scope_for_admin = Domain::Shared::Policies::AgriculturalTaskPolicy.visible_scope(AgriculturalTask, @admin)

    # 一般ユーザー: 自分の非参照タスクのみ
    assert_includes scope_for_user, user_task
    assert_not_includes scope_for_user, reference_task
    assert_not_includes scope_for_user, admin_task

    # 管理者: 参照タスク + 自分のタスク
    assert_includes scope_for_admin, reference_task
    assert_includes scope_for_admin, admin_task
    assert_not_includes scope_for_admin, user_task
  end

  test 'user_owned_non_reference_scope returns only non-reference tasks owned by given user' do
    reference_task = create(:agricultural_task)
    user_task = create(:agricultural_task, :user_owned, user: @user)
    other_user_task = create(:agricultural_task, :user_owned, user: create(:user))

    scope = Domain::Shared::Policies::AgriculturalTaskPolicy.user_owned_non_reference_scope(AgriculturalTask, @user)

    assert_includes scope, user_task
    assert_not_includes scope, reference_task
    assert_not_includes scope, other_user_task
  end
end
