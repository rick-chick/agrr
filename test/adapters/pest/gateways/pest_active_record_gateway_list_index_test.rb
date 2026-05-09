# frozen_string_literal: true

require "test_helper"

module Adapters
  module Pest
    module Gateways
      class PestActiveRecordGatewayListIndexTest < ActiveSupport::TestCase
        setup do
          @gw = PestActiveRecordGateway.new(deletion_undo_gateway: CompositionRoot.deletion_undo_gateway)
        end

        test "list_index_for_filter owned_non_reference returns only that user's non-reference pests" do
          user = create(:user)
          other = create(:user)
          owned = create(:pest, :user_owned, user: user, name: "Mine")
          create(:pest, :reference, name: "System ref")
          create(:pest, :user_owned, user: other, name: "Other user")

          filter = Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :owned_non_reference, user_id: user.id)
          ids = @gw.list_index_for_filter(filter).map(&:id)

          assert_equal [ owned.id ], ids
        end

        test "list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id" do
          admin = create(:user, admin: true)
          ref = create(:pest, :reference, name: "Ref")
          own = create(:pest, :user_owned, user: admin, name: "Admin own")
          other_user = create(:user)
          other_pest = create(:pest, :user_owned, user: other_user, name: "Someone else")

          filter = Domain::Shared::ValueObjects::ReferenceIndexListFilter.new(mode: :reference_or_owned, user_id: admin.id)
          ids = @gw.list_index_for_filter(filter).map(&:id)

          assert_includes ids, ref.id
          assert_includes ids, own.id
          assert_not_includes ids, other_pest.id
        end
      end
    end
  end
end
