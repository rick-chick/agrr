# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldDestroyInteractorTest < DomainLibTestCase
  test "call passes FieldDestroyOutput to output port on success" do
    undo_payload = { undo_token: "tok", toast_message: "m", undo_path: "/u" }

    user = stub(id: 20)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:destroy).with(7, farm_access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)).returns(undo_payload)

    output = mock
    output.expects(:on_success).with do |arg|
      assert_instance_of Domain::Field::Dtos::FieldDestroyOutput, arg
      assert_equal undo_payload, arg.undo
      true
    end

    interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(7)
  end

  test "call forwards RecordNotFound to on_failure as Error" do
    user = stub(id: 20)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:destroy).raises(Domain::Shared::Exceptions::RecordNotFound.new("Field not found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Dtos::Error, err
      assert_equal "Field not found", err.message
      true
    end

    interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(7)
  end

  test "call forwards policy permission denied to on_failure as exception" do
    err = Domain::Shared::Policies::PolicyPermissionDenied.new
    user = stub(id: 20)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:destroy).raises(err)

    output = mock
    output.expects(:on_failure).with(err)

    interactor = Domain::Field::Interactors::FieldDestroyInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(7)
  end
end
