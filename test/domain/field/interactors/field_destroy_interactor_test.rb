# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldDestroyInteractorTest < DomainLibTestCase
  test "call passes FieldDestroyOutput to output port on success" do
    undo_payload = { undo_token: "tok", toast_message: "m", undo_path: "/u" }
    farm_entity = domain_record_entity_stub(user_id: 20, is_reference: false)
    with_farm = stub(farm: farm_entity)

    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)
    stub_field_access_find_owned!(user, 7)

    gateway = mock
    gateway.expects(:field_with_farm).with(7).returns(with_farm)
    gateway.expects(:delete).with(7).returns(undo_payload)

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
    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)
    stub_field_access_find_owned!(user, 7)

    gateway = mock
    gateway.expects(:field_with_farm).raises(Domain::Shared::Exceptions::RecordNotFound.new("Field not found"))

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
    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)
    stub_field_access_find_owned!(user, 7, error: err)

    gateway = mock
    gateway.expects(:field_with_farm).never
    gateway.expects(:delete).never

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
