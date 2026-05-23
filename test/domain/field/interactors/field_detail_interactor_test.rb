# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldDetailInteractorTest < DomainLibTestCase
  test "call passes FieldWithFarm to output port on success" do
    farm_entity = Domain::Farm::Entities::FarmEntity.new(
      id: 1, name: "F", latitude: nil, longitude: nil, region: nil, user_id: 20,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1), is_reference: false
    )
    field_entity = Domain::Field::Entities::FieldEntity.new(
      id: 2, farm_id: 1, user_id: 20, name: "North", description: nil,
      created_at: Time.utc(2026, 1, 1), updated_at: Time.utc(2026, 1, 1), area: nil, daily_fixed_cost: nil, region: nil
    )
    result = Domain::Field::Results::FieldWithFarm.new(farm: farm_entity, field: field_entity)

    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)
    stub_field_access_find_owned!(user, 5)

    gateway = mock
    gateway.expects(:field_with_farm).with(5).returns(result)

    output = mock
    output.expects(:on_success).with do |arg|
      assert_equal farm_entity, arg.farm
      assert_equal field_entity, arg.field
      true
    end

    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    input = Domain::Field::Dtos::FieldDetailInput.new(field_id: 5)
    interactor.call(input)
  end

  test "call forwards RecordNotFound to on_failure as FieldDetailFailure with farm_id" do
    user = domain_user_stub(id: 20, admin: false)
    user_lookup = mock
    user_lookup.expects(:find).with(20).returns(user)

    gateway = mock
    gateway.expects(:field_with_farm).raises(Domain::Shared::Exceptions::RecordNotFound.new("Field not found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_instance_of Domain::Field::Dtos::FieldDetailFailure, err
      assert_equal "Field not found", err.message
      assert_equal 3, err.farm_id
      true
    end

    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      user_lookup: user_lookup
    )
    input = Domain::Field::Dtos::FieldDetailInput.new(field_id: 5, farm_id: 3)
    interactor.call(input)
  end
end
