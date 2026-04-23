# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::PestPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for regular user forces non-reference" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(@user, { name: "P", is_reference: true })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "view_allowed? for reference pest" do
    assert Domain::Shared::Policies::PestPolicy.view_allowed?(@user, is_reference: true, user_id: nil)
  end
end
