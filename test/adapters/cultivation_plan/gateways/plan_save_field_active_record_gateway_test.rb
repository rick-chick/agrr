# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveFieldActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveFieldActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-field-#{SecureRandom.hex(4)}@example.com",
            name: "Field GW User",
            google_id: "plan-save-field-#{SecureRandom.hex(8)}"
          )
          @farm = ::Farm.create!(
            user: @user,
            name: "圃場GW",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            is_reference: false
          )
        end

        test "list_by_farm_id returns field snapshots ordered by id" do
          f1 = @farm.fields.create!(user: @user, name: "A", area: 1.0)
          f2 = @farm.fields.create!(user: @user, name: "B", area: 2.0)

          snapshots = @gateway.list_by_farm_id(farm_id: @farm.id, user_id: @user.id)

          assert_equal [ f1.id, f2.id ], snapshots.map(&:id)
          assert snapshots.all? { |e| e.is_a?(Domain::CultivationPlan::Dtos::PlanSaveFieldSnapshot) }
        end

        test "create persists field with description from attributes" do
          snapshot = @gateway.create(
            farm_id: @farm.id,
            user_id: @user.id,
            attributes: {
              name: "区画A",
              area: 12.5,
              description: "lat/lng"
            }
          )

          assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveFieldSnapshot, snapshot

          record = ::Field.find(snapshot.id)
          assert_equal "区画A", record.name
          assert_in_delta 12.5, record.area.to_f, 0.001
          assert_equal "lat/lng", record.description
          assert_equal @user.id, record.user_id
        end

      end
    end
  end
end
