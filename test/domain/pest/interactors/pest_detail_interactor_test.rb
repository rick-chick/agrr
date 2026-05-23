# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Interactors
      class PestDetailInteractorTest < DomainLibTestCase
        test "calls on_success with detail dto when view is allowed" do
          user_id = 10
          pest_id = 3
          user = stub(id: user_id, admin?: false)
          pest_entity = stub(is_reference: true, user_id: nil)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          detail_dto = stub(pest: pest_entity)
          gateway.expects(:find_pest_show_detail).with(pest_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          translator = Minitest::Mock.new

          interactor = PestDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            translator: translator,
            gateway: gateway,
            user_lookup: user_lookup
          )

          interactor.call(pest_id)

          assert_equal detail_dto, received
          user_lookup.verify
          output_port.verify
        end

        test "calls on_failure with no_permission when view is denied" do
          user_id = 10
          pest_id = 3
          user = stub(id: user_id, admin?: false)
          pest_entity = stub(is_reference: false, user_id: 99)

          user_lookup = Minitest::Mock.new
          user_lookup.expect(:find, user, [ user_id ])

          gateway = mock
          detail_dto = stub(pest: pest_entity)
          gateway.expects(:find_pest_show_detail).with(pest_id).returns(detail_dto)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          translator = Minitest::Mock.new
          translator.expect(:t, "no permission", [ "pests.flash.no_permission" ])

          interactor = PestDetailInteractor.new(
            output_port: output_port,
            user_id: user_id,
            translator: translator,
            gateway: gateway,
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
