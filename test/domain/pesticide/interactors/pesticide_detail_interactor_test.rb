# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractorTest < DomainLibTestCase
        PesticideWire = Data.define(
          :id,
          :user_id,
          :name,
          :active_ingredient,
          :description,
          :crop_id,
          :pest_id,
          :region,
          :is_reference,
          :created_at,
          :updated_at
        )

        PesticideShowDetailWire = Data.define(
          :pesticide,
          :crop_name,
          :pest_name,
          :usage_constraint,
          :application_detail
        )

        test "calls on_success with detail dto when view is allowed" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          pesticide_wire = PesticideWire.new(
            id: pesticide_id,
            user_id: user_id,
            name: "農薬",
            active_ingredient: nil,
            description: nil,
            crop_id: 1,
            pest_id: 2,
            region: nil,
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = PesticideShowDetailWire.new(
            pesticide: pesticide_wire,
            crop_name: "トマト",
            pest_name: "アブラムシ",
            usage_constraint: nil,
            application_detail: nil
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(pesticide_id: pesticide_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Pesticide::Dtos::PesticideDetailOutput, received
          assert_equal pesticide_id, received.pesticide.id
          assert_equal "トマト", received.crop_name
          assert_equal "アブラムシ", received.pest_name
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when reference pesticide is not visible" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          pesticide_wire = PesticideWire.new(
            id: pesticide_id,
            user_id: nil,
            name: "農薬",
            active_ingredient: nil,
            description: nil,
            crop_id: 1,
            pest_id: 2,
            region: nil,
            is_reference: true,
            created_at: now,
            updated_at: now
          )
          wire = PesticideShowDetailWire.new(
            pesticide: pesticide_wire,
            crop_name: nil,
            pest_name: nil,
            usage_constraint: nil,
            application_detail: nil
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(pesticide_id: pesticide_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with policy exception when other user pesticide" do
          user_id = 10
          pesticide_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          pesticide_wire = PesticideWire.new(
            id: pesticide_id,
            user_id: 99,
            name: "農薬",
            active_ingredient: nil,
            description: nil,
            crop_id: 1,
            pest_id: 2,
            region: nil,
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = PesticideShowDetailWire.new(
            pesticide: pesticide_wire,
            crop_name: nil,
            pest_name: nil,
            usage_constraint: nil,
            application_detail: nil
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(pesticide_id: pesticide_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = PesticideDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(pesticide_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
          user_lookup.verify
          output_port.verify
        end
      end
    end
  end
end
