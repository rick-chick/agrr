# frozen_string_literal: true

require "test_helper"

class Adapters::Pesticide::Gateways::PesticideActiveRecordGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator,
      crop_gateway: CompositionRoot.crop_gateway,
      pest_gateway: CompositionRoot.pest_gateway
    )
    @user = create(:user)
  end

  test "list_index_for_filter owned_non_reference returns only that user's non-reference pesticides" do
    user = create(:user)
    other = create(:user)
    crop_u = create(:crop, :user_owned, user: user)
    pest_u = create(:pest, :user_owned, user: user)
    owned = create(:pesticide, :user_owned, user: user, crop: crop_u, pest: pest_u, name: "Mine")
    crop_o = create(:crop, :user_owned, user: other)
    pest_o = create(:pest, :user_owned, user: other)
    create(:pesticide, :user_owned, user: other, crop: crop_o, pest: pest_o, name: "Other")
    crop_r = create(:crop, :reference)
    pest_r = create(:pest, :reference)
    create(:pesticide, :reference, crop: crop_r, pest: pest_r, name: "Ref")

    filter = Domain::Shared::Policies::PesticidePolicy.index_list_filter(user)
    ids = @gateway.list_index_for_filter(filter).map(&:id)

    assert_equal [ owned.id ], ids
  end

  test "list_index_for_filter reference_or_owned includes reference and admin-owned rows" do
    admin = create(:user, admin: true)
    crop_a = create(:crop, :user_owned, user: admin)
    pest_a = create(:pest, :user_owned, user: admin)
    own = create(:pesticide, :user_owned, user: admin, crop: crop_a, pest: pest_a, name: "Admin own")
    crop_r = create(:crop, :reference)
    pest_r = create(:pest, :reference)
    ref = create(:pesticide, :reference, crop: crop_r, pest: pest_r, name: "Ref")
    other = create(:user)
    crop_o = create(:crop, :user_owned, user: other)
    pest_o = create(:pest, :user_owned, user: other)
    other_pesticide = create(:pesticide, :user_owned, user: other, crop: crop_o, pest: pest_o, name: "Other")

    filter = Domain::Shared::Policies::PesticidePolicy.index_list_filter(admin)
    ids = @gateway.list_index_for_filter(filter).map(&:id)

    assert_includes ids, ref.id
    assert_includes ids, own.id
    assert_not_includes ids, other_pesticide.id
  end
end
