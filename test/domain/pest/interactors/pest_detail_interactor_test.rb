# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestDetailInteractorTest < DomainLibTestCase
        PestWire = Data.define(
          :id,
          :user_id,
          :name,
          :name_scientific,
          :family,
          :order,
          :description,
          :occurrence_season,
          :region,
          :is_reference,
          :created_at,
          :updated_at
        )

        PestShowDetailWire = Data.define(
          :pest,
          :temperature_profile,
          :thermal_requirement,
          :control_methods,
          :crops
        )

        test "calls on_success with detail dto when view is allowed" do
          user_id = 10
          pest_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          pest_wire = PestWire.new(
            id: pest_id,
            user_id: nil,
            name: "害虫",
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            region: nil,
            is_reference: true,
            created_at: now,
            updated_at: now
          )
          wire = PestShowDetailWire.new(
            pest: pest_wire,
            temperature_profile: nil,
            thermal_requirement: nil,
            control_methods: [],
            crops: []
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(pest_id: pest_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          translator = Minitest::Mock.new

          interactor = PestDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            translator: translator,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(pest_id)

          assert_instance_of Domain::Pest::Dtos::PestDetailOutput, received
          assert_equal pest_id, received.pest.id
          assert received.pest.is_reference
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with no_permission when view is denied" do
          user_id = 10
          pest_id = 3
          user = stub(id: user_id, admin?: false)
          now = Time.utc(2026, 1, 1)
          pest_wire = PestWire.new(
            id: pest_id,
            user_id: 99,
            name: "害虫",
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            region: nil,
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = PestShowDetailWire.new(
            pest: pest_wire,
            temperature_profile: nil,
            thermal_requirement: nil,
            control_methods: [],
            crops: []
          )

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          show_detail_read_gateway = mock
          show_detail_read_gateway.expects(:find_show_detail_snapshot).with(pest_id: pest_id).returns(wire)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          translator = Minitest::Mock.new
          translator.expect(:t, "no permission", [ "pests.flash.no_permission" ])

          interactor = PestDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            translator: translator,
            show_detail_read_gateway: show_detail_read_gateway,
            user_lookup: user_lookup
          )

          interactor.call(pest_id)

          assert_instance_of Domain::Shared::Dtos::Error, received
          assert_equal "no permission", received.message
          user_lookup.verify
          output_port.verify
          translator.verify
        end
      end
    end
  end
end
