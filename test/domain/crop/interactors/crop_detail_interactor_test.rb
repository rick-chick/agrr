# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropDetailInteractorTest < DomainLibTestCase
        CropWire = Data.define(
          :id,
          :user_id,
          :name,
          :variety,
          :is_reference,
          :area_per_unit,
          :revenue_per_area,
          :region,
          :groups,
          :created_at,
          :updated_at,
          :crop_stages,
          :pests
        )

        test "calls on_success with crop detail dto when read gateway returns wire" do
          user_id = 10
          crop_id = 22
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          wire = CropWire.new(
            id: crop_id,
            user_id: user_id,
            name: "トマト",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            created_at: now,
            updated_at: now,
            crop_stages: [],
            pests: []
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(crop_id: crop_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_instance_of Domain::Crop::Dtos::CropDetailOutput, received
          assert_equal crop_id, received.crop.id
          assert_equal user_id, received.crop.user_id
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when permission is denied" do
          user_id = 10
          crop_id = 22
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          wire = CropWire.new(
            id: crop_id,
            user_id: 99,
            name: "トマト",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            created_at: now,
            updated_at: now,
            crop_stages: [],
            pests: []
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(crop_id: crop_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(crop_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
