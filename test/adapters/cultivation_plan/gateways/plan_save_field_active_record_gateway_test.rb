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

        test "list_by_farm_id returns field entities ordered by id" do
          f1 = @farm.fields.create!(user: @user, name: "A", area: 1.0)
          f2 = @farm.fields.create!(user: @user, name: "B", area: 2.0)

          entities = @gateway.list_by_farm_id(farm_id: @farm.id, user_id: @user.id)

          assert_equal [ f1.id, f2.id ], entities.map(&:id)
          assert entities.all? { |e| e.is_a?(Domain::Field::Entities::FieldEntity) }
        end

        test "list_by_ids returns fields in caller order scoped to user" do
          f1 = @farm.fields.create!(user: @user, name: "A", area: 1.0)
          f2 = @farm.fields.create!(user: @user, name: "B", area: 2.0)

          ordered = @gateway.list_by_ids(ids: [ f2.id, f1.id ], user_id: @user.id)

          assert_equal [ f2.id, f1.id ], ordered.map(&:id)
        end

        test "create persists field with description from attributes" do
          entity = @gateway.create(
            farm_id: @farm.id,
            user_id: @user.id,
            attributes: {
              name: "区画A",
              area: 12.5,
              description: "lat/lng"
            }
          )

          record = ::Field.find(entity.id)
          assert_equal "区画A", record.name
          assert_in_delta 12.5, record.area.to_f, 0.001
          assert_equal "lat/lng", record.description
          assert_equal @user.id, record.user_id
        end

      end
    end
  end
end
