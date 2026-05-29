# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmDetailInteractorTest < DomainLibTestCase
        FarmWire = Data.define(
          :id,
          :name,
          :latitude,
          :longitude,
          :region,
          :user_id,
          :created_at,
          :updated_at,
          :is_reference,
          :weather_data_status,
          :weather_data_fetched_years,
          :weather_data_total_years,
          :weather_data_last_error,
          :last_broadcast_at
        )

        FarmShowDetailWire = Data.define(:farm, :fields)

        test "calls on_success when read gateway returns wire" do
          user_id = 10
          farm_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          farm_wire = FarmWire.new(
            id: farm_id,
            name: "農場",
            latitude: 35.0,
            longitude: 135.0,
            region: "jp",
            user_id: user_id,
            created_at: now,
            updated_at: now,
            is_reference: false,
            weather_data_status: nil,
            weather_data_fetched_years: nil,
            weather_data_total_years: nil,
            weather_data_last_error: nil,
            last_broadcast_at: nil
          )
          wire = FarmShowDetailWire.new(farm: farm_wire, fields: [])

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(farm_id).returns(stub(is_reference: false, user_id: user_id))

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(farm_id: farm_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            show_detail_read_gateway: show_detail_read_gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(farm_id)

          assert_instance_of Domain::Farm::Dtos::FarmDetailOutput, received
          assert_equal farm_id, received.farm.id
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission denied" do
          user_id = 10
          farm_id = 3
          user = stub(id: user_id, admin?: false)
          farm_entity = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          gateway.expects(:find_by_id).with(farm_id).returns(farm_entity)
          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).never

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = FarmDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            gateway: gateway,
            show_detail_read_gateway: show_detail_read_gateway,
            translator: Object.new,
            user_lookup: user_lookup
          )

          interactor.call(farm_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
