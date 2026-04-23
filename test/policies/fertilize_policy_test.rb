# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::FertilizePolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for regular user" do
    h = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(@user, { name: "F", is_reference: false })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "view_allowed? for own non-reference" do
    assert Domain::Shared::Policies::FertilizePolicy.view_allowed?(@user, is_reference: false, user_id: @user.id)
  end

  test "view_allowed? denies reference for non-admin" do
    assert_not Domain::Shared::Policies::FertilizePolicy.view_allowed?(@user, is_reference: true, user_id: nil)
  end
end
