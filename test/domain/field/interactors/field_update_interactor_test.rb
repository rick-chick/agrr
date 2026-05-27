# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldUpdateInteractorTest < DomainLibTestCase
  test "call passes FieldEntity to output port on success" do
    field_entity = Domain::Field::Entities::FieldEntity.new(
      id: 5, farm_id: 1, user_id: 9, name: "Updated", description: nil,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1), area: nil, daily_fixed_cost: nil, region: nil
    )
    dto = Domain::Field::Dtos::FieldUpdateInput.new(id: 5, name: "Updated")
    farm_entity = domain_record_entity_stub(user_id: 20, is_reference: false)
    with_farm = stub(farm: farm_entity)

    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:field_with_farm).with(5).returns(with_farm)
    gateway.expects(:update).with(5, dto).returns(field_entity)

    output = mock
    output.expects(:on_success).with(field_entity)

    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(dto)
  end

  test "call forwards RecordNotFound to on_failure as Error" do
    dto = Domain::Field::Dtos::FieldUpdateInput.new(id: 5, name: "X")
    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:field_with_farm).raises(Domain::Shared::Exceptions::RecordNotFound.new("Field not found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Dtos::Error, err
      assert_equal "Field not found", err.message
      true
    end

    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(dto)
  end

  test "call forwards policy permission denied to on_failure as exception" do
    dto = Domain::Field::Dtos::FieldUpdateInput.new(id: 5, name: "X")
    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)
    other_farm = domain_record_entity_stub(user_id: 99, is_reference: false)
    gateway = mock
    gateway.expects(:field_with_farm).with(5).returns(stub(farm: other_farm))
    gateway.expects(:update).never

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, err
      true
    end

    interactor = Domain::Field::Interactors::FieldUpdateInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    interactor.call(dto)
  end
end
