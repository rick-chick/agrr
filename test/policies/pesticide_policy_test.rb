# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::PesticidePolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for regular user" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(@user, { name: "P", is_reference: false })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "view_allowed? uses referencable rule" do
    refute Domain::Shared::Policies::PesticidePolicy.view_allowed?(@user, is_reference: true, user_id: nil)
    assert Domain::Shared::Policies::PesticidePolicy.view_allowed?(@admin, is_reference: true, user_id: nil)
  end
end
