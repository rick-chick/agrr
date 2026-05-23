# frozen_string_literal: true

require "domain_lib_test_helper"

class FertilizeDestroyInteractorTest < DomainLibTestCase
  test "calls on_failure with policy exception when permission denied" do
    user_id = 10
    user = domain_user_stub(id: user_id, admin: false)
    fertilize_id = 7
    fertilize_entity = domain_record_entity_stub(user_id: 99, is_reference: false)

    user_lookup = Minitest::Mock.new
    user_lookup.expect(:find, user, [ user_id ])

    gateway = mock
    gateway.expects(:find_by_id).with(fertilize_id).returns(fertilize_entity)
    gateway.expects(:soft_delete_with_undo).never

    received = nil
    output_port = Minitest::Mock.new
    output_port.expect(:on_failure, nil) { |arg| received = arg }

    interactor = Domain::Fertilize::Interactors::FertilizeDestroyInteractor.new(
      output_port: output_port,
      gateway: gateway,
      user_id: user_id,
      translator: Object.new,
      user_lookup: user_lookup
    )

    interactor.call(fertilize_id)

    assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
    user_lookup.verify
    output_port.verify
  end
end
