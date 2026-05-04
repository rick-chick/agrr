# frozen_string_literal: true

require "test_helper"

class FieldListInteractorTest < ActiveSupport::TestCase
  test "call passes FarmFieldsList to output port on success" do
    farm_entity = Domain::Farm::Entities::FarmEntity.new(
      id: 1, name: "F", latitude: nil, longitude: nil, region: nil, user_id: 9,
      created_at: Time.current, updated_at: Time.current, is_reference: false
    )
    field_entity = Domain::Field::Entities::FieldEntity.new(
      id: 2, farm_id: 1, user_id: 9, name: "North", description: nil,
      created_at: Time.current, updated_at: Time.current, area: nil, daily_fixed_cost: nil, region: nil
    )
    result = Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: [ field_entity ])

    gateway = mock
    gateway.expects(:translator=).with(:tr)
    gateway.expects(:authorized_farm_fields_list).with(10, 20).returns(result)

    output = mock
    output.expects(:on_success).with do |arg|
      assert_equal farm_entity, arg.farm
      assert_equal [ field_entity ], arg.fields
      true
    end

    interactor = Domain::Field::Interactors::FieldListInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
      translator: :tr
    )
    interactor.call(10)
  end

  test "call forwards errors to on_failure" do
    gateway = mock
    gateway.expects(:translator=).with(:tr)
    gateway.expects(:authorized_farm_fields_list).raises(StandardError.new("boom"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "boom", err.message
      true
    end

    interactor = Domain::Field::Interactors::FieldListInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
      translator: :tr
    )
    interactor.call(10)
  end

  test "call forwards policy permission denied to on_failure as exception" do
    err = Domain::Shared::Policies::PolicyPermissionDenied.new
    gateway = mock
    gateway.expects(:translator=).with(:tr)
    gateway.expects(:authorized_farm_fields_list).with(10, 20).raises(err)

    output = mock
    output.expects(:on_failure).with(err)

    interactor = Domain::Field::Interactors::FieldListInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
      translator: :tr
    )
    interactor.call(10)
  end
end
