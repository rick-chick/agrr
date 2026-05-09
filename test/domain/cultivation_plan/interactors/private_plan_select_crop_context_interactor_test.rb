# frozen_string_literal: true

require "test_helper"

class PrivatePlanSelectCropContextInteractorTest < ActiveSupport::TestCase
  test "call passes dto with farm, crops, total_area from gateways" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(7).returns(user)

    farm_entity = Domain::Farm::Entities::FarmEntity.new(
      id: 1,
      name: "My Farm",
      latitude: 35.0,
      longitude: 135.0,
      region: "ja",
      user_id: 7,
      created_at: Time.current,
      updated_at: Time.current,
      is_reference: false
    )

    field1 = Domain::Field::Entities::FieldEntity.new(
      id: 10, farm_id: 1, user_id: 7, name: "A", description: nil,
      created_at: Time.current, updated_at: Time.current, area: 10.0,
      daily_fixed_cost: 0, region: nil
    )
    field2 = Domain::Field::Entities::FieldEntity.new(
      id: 11, farm_id: 1, user_id: 7, name: "B", description: nil,
      created_at: Time.current, updated_at: Time.current, area: 20.5,
      daily_fixed_cost: 0, region: nil
    )
    farm_fields = Domain::Field::Results::FarmFieldsList.new(farm: farm_entity, fields: [ field1, field2 ])

    crop_entities = [ mock, mock ]

    field_gateway = mock
    field_gateway.expects(:authorized_farm_fields_list).with(1, farm_access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)).returns(farm_fields)

    crop_gateway = mock
    crop_gateway.expects(:list_user_owned_non_reference_crops_ordered_by_name).with(user).returns(crop_entities)

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_success).with do |dto|
      assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanSelectCropContextDto, dto
      assert_equal farm_entity, dto.farm
      assert_equal "My Farm", dto.plan_name
      assert_equal crop_entities, dto.crops
      assert_in_delta 30.5, dto.total_area.to_f, 0.001
      true
    end

    interactor = Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor.new(
      output_port: output,
      user_id: 7,
      farm_id: 1,
      field_gateway: field_gateway,
      crop_gateway: crop_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    )
    interactor.call
  end

  test "call forwards RecordNotFound to on_failure with translated message" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(7).returns(user)

    field_gateway = mock
    field_gateway.expects(:authorized_farm_fields_list).raises(Domain::Shared::Exceptions::RecordNotFound.new("x"))

    crop_gateway = mock
    translator = mock
    translator.expects(:t).with("plans.errors.farm_not_found").returns("農場が見つかりません。")
    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "農場が見つかりません。", err.message
      true
    end

    interactor = Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor.new(
      output_port: output,
      user_id: 7,
      farm_id: 999,
      field_gateway: field_gateway,
      crop_gateway: crop_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    )
    interactor.call
  end

  test "propagates unexpected StandardError from field_gateway" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(7).returns(user)

    field_gateway = mock
    field_gateway.expects(:authorized_farm_fields_list).raises(StandardError.new("internal detail"))

    crop_gateway = mock
    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    interactor = Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor.new(
      output_port: output,
      user_id: 7,
      farm_id: 1,
      field_gateway: field_gateway,
      crop_gateway: crop_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    )

    err = assert_raises(StandardError) do
      interactor.call
    end
    assert_equal "internal detail", err.message
  end
end
