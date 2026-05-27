# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserFertilizeActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserFertilizeActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-fert-#{SecureRandom.hex(4)}@example.com",
            name: "Fertilize GW User",
            google_id: "plan-save-fert-#{SecureRandom.hex(8)}"
          )
          @reference = ::Fertilize.create!(
            user: nil,
            name: "参照肥料#{SecureRandom.hex(4)}",
            n: 10,
            p: 5,
            k: 8,
            is_reference: true,
            region: "jp"
          )
        end

        test "find_by_user_id_and_source_fertilize_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_fertilize_id(
            user_id: @user.id,
            source_fertilize_id: @reference.id
          )
        end

        test "create and find round-trip" do
          copy_name = "ユーザー肥料#{SecureRandom.hex(4)}"
          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              name: copy_name,
              n: @reference.n,
              p: @reference.p,
              k: @reference.k,
              is_reference: false,
              region: "jp",
              source_fertilize_id: @reference.id
            }
          )

          found = @gateway.find_by_user_id_and_source_fertilize_id(
            user_id: @user.id,
            source_fertilize_id: @reference.id
          )
          assert_equal created.id, found.id
          assert_equal copy_name, found.name
        end
      end
    end
  end
end
