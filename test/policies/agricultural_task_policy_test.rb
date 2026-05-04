# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::AgriculturalTaskPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for regular user" do
    h = Domain::Shared::Policies::AgriculturalTaskPolicy.normalize_attrs_for_create(@user, { name: "T", is_reference: false })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "masters_crop_task_template_associate_allowed? allows reference task for another owner" do
    other = create(:user)
    assert Domain::Shared::Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
      @user,
      is_reference: true,
      user_id: other.id
    )
  end

  test "masters_crop_task_template_associate_allowed? allows own non-reference task" do
    assert Domain::Shared::Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
      @user,
      is_reference: false,
      user_id: @user.id
    )
  end

  test "masters_crop_task_template_associate_allowed? rejects other user non-reference task" do
    other = create(:user)
    assert_not Domain::Shared::Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
      @user,
      is_reference: false,
      user_id: other.id
    )
  end

  test "view_allowed? for own task" do
    assert Domain::Shared::Policies::AgriculturalTaskPolicy.view_allowed?(@user, is_reference: false, user_id: @user.id)
  end
end
