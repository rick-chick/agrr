# frozen_string_literal: true

require "test_helper"

module Adapters
  module Field
    module Gateways
      class FieldActiveRecordGatewayTest < ActiveSupport::TestCase
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
