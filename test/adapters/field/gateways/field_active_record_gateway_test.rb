# frozen_string_literal: true

require "test_helper"

module Adapters
  module Field
    module Gateways
      class FieldActiveRecordGatewayTest < ActiveSupport::TestCase
        test "get_total_area_by_farm_id sums field areas" do
          user = create(:user)
          farm = create(:farm, user: user)
          create(:field, farm: farm, user: user, area: 10.5)
          create(:field, farm: farm, user: user, area: 20.0)

          gateway = CompositionRoot.field_gateway

          assert_in_delta 30.5, gateway.get_total_area_by_farm_id(farm_id: farm.id), 0.001
        end

        test "farm_fields_list returns fields for farm" do
          user = create(:user)
          farm = create(:farm, user: user)
          create(:field, farm: farm, user: user, name: "North")

          gateway = CompositionRoot.field_gateway

          list = gateway.farm_fields_list(farm.id)

          assert_kind_of Domain::Field::Results::FarmFieldsList, list
          assert_equal 1, list.fields.size
        end

      end
    end
  end
end
