# frozen_string_literal: true

require "test_helper"

class FieldDetailInteractorTest < ActiveSupport::TestCase
  test "call passes FieldWithFarm to output port on success" do
    farm_entity = Domain::Farm::Entities::FarmEntity.new(
      id: 1, name: "F", latitude: nil, longitude: nil, region: nil, user_id: 9,
      created_at: Time.current, updated_at: Time.current, is_reference: false
    )
    field_entity = Domain::Field::Entities::FieldEntity.new(
      id: 2, farm_id: 1, user_id: 9, name: "North", description: nil,
      created_at: Time.current, updated_at: Time.current, area: nil, daily_fixed_cost: nil, region: nil
    )
    result = Domain::Field::Results::FieldWithFarm.new(farm: farm_entity, field: field_entity)

    gateway = mock
    gateway.expects(:translator=).with(:tr)
    gateway.expects(:field_with_farm_for_user).with(5, 20).returns(result)

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
      logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
      translator: :tr
    )
    interactor.call(5)
  end

  test "call forwards errors to on_failure" do
    gateway = mock
    gateway.expects(:translator=).with(:tr)
    gateway.expects(:field_with_farm_for_user).raises(StandardError.new("boom"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "boom", err.message
      true
    end

    interactor = Domain::Field::Interactors::FieldDetailInteractor.new(
      output_port: output,
      user_id: 20,
      gateway: gateway,
      logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
      translator: :tr
    )
    interactor.call(5)
  end
end
