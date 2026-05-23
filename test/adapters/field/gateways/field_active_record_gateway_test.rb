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

        test "build_blank_field_for_master_form! returns snapshot for new field in authorized farm" do
          user = create(:user)
          farm = create(:farm, user: user)
          gateway = CompositionRoot.field_gateway
          filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)

          snap = gateway.build_blank_field_for_master_form!(farm_id: farm.id, farm_access_filter: filter)

          assert_instance_of Domain::Farm::Dtos::FieldMasterFormSnapshot, snap
          assert snap.new_record?
          assert_nil snap.id
          form = Forms::FieldMasterForm.from_snapshot(snap)
          assert form.new_record?
          assert_equal farm.id, form.farm_id
        end
      end
    end
  end
end
