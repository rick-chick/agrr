# frozen_string_literal: true

require "test_helper"

class Adapters::Fertilize::Gateways::FertilizeActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
  end

  test "build_blank_fertilize_for_master_form returns new unsaved fertilize" do
    fertilize = @gateway.build_blank_fertilize_for_master_form

    assert_instance_of ::Fertilize, fertilize
    assert fertilize.new_record?
  end

  test "list_index_for_user returns only named user-owned non-reference fertilizes for regular user" do
    user = create(:user)
    other = create(:user)
    a = create(:fertilize, :user_owned, user: user, name: "Owned A")
    b = create(:fertilize, :user_owned, user: user, name: "Owned B")
    create(:fertilize, :reference, name: "System Ref")
    create(:fertilize, :user_owned, user: other, name: "Other user row")
    blank_name = create(:fertilize, :user_owned, user: user, name: "Temp")
    blank_name.update_column(:name, "")

    ids = @gateway.list_index_for_user(user).map(&:id).sort

    assert_equal [ a.id, b.id ].sort, ids
  end

  test "list_index_for_user for admin includes reference and own user-owned rows" do
    admin = create(:user, admin: true)
    ref = create(:fertilize, :reference, name: "Ref row")
    own = create(:fertilize, :user_owned, user: admin, name: "Admin own")

    ids = @gateway.list_index_for_user(admin).map(&:id)

    assert_includes ids, ref.id
    assert_includes ids, own.id
  end
end
