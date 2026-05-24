# frozen_string_literal: true

# 作物編集認可の拒否・欠損は CropMastersCropEditAccessTest で表明。
require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropMastersTaskTemplateCreateInteractorTest < DomainLibTestCase
        setup do
          @fixed_at = Time.utc(2026, 1, 15, 12, 0, 0).freeze
          @gateway = mock
          @crop_task_template_gateway = mock
          @agricultural_task_gateway = mock
          @output_port = mock
          @user_lookup = mock
          @interactor = CropMastersTaskTemplateCreateInteractor.new(
            output_port: @output_port,
            gateway: @gateway,
            crop_task_template_gateway: @crop_task_template_gateway,
            user_lookup: @user_lookup,
            agricultural_task_gateway: @agricultural_task_gateway
          )
        end

        def crop_entity
          Entities::CropEntity.new(
            id: 2,
            user_id: 1,
            name: "Foo",
            variety: nil,
            is_reference: false,
            area_per_unit: nil,
            revenue_per_area: nil,
            region: nil,
            groups: [],
            crop_stages: [],
            created_at: @fixed_at,
            updated_at: @fixed_at
          )
        end

        test "should create association successfully" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          task_entity = stub(
            id: 3,
            is_reference: false,
            user_id: 1,
            name: "T",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil
          )
          template_entity = Entities::CropTaskTemplateEntity.new(
            id: 10,
            crop_id: 2,
            agricultural_task_id: 3,
            name: "T",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil,
            created_at: @fixed_at,
            updated_at: @fixed_at
          )
          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_entity)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @crop_task_template_gateway.expects(:find_by_agricultural_task_id_and_crop_id).with(
            agricultural_task_id: 3,
            crop_id: 2
          ).returns(nil)
          @crop_task_template_gateway.expects(:create_detail).with(
            crop_id: 2,
            agricultural_task_id: 3,
            attributes: instance_of(Domain::Crop::Dtos::CropTaskTemplatePersistAttributes)
          ).returns(template_entity)
          @output_port.expects(:on_success).with do |dto|
            assert_equal 10, dto.id
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural_task_id missing" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: nil
          )

          @user_lookup.expects(:find).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :missing_agricultural_task_id, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when crop not found" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :crop_not_found, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when agricultural task not found" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_entity)
          @agricultural_task_gateway.expects(:find_by_id).with(3).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :agricultural_task_not_found, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when association is forbidden" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          task_entity = stub(is_reference: false, user_id: 99)

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_entity)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :forbidden, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when association is duplicate" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          task_entity = stub(
            id: 3,
            is_reference: false,
            user_id: 1,
            name: "T",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil
          )
          existing = stub

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_entity)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @crop_task_template_gateway.expects(:find_by_agricultural_task_id_and_crop_id).returns(existing)
          @crop_task_template_gateway.expects(:create_detail).never
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :duplicate, failure_dto.reason
            true
          end

          @interactor.call(input_dto)
        end

        test "should return failure when validation fails" do
          input_dto = Domain::Crop::Dtos::MastersCropTaskTemplateCreateInput.new(
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: 3
          )
          user = stub(id: 1, admin?: false)
          task_entity = stub(
            id: 3,
            is_reference: false,
            user_id: 1,
            name: "T",
            description: nil,
            time_per_sqm: nil,
            weather_dependency: nil,
            required_tools: [],
            skill_level: nil
          )
          record_invalid = Domain::Shared::Exceptions::RecordInvalid.new(
            "invalid",
            errors: [ "Name can't be blank" ]
          )

          @user_lookup.expects(:find).with(1).returns(user)
          @gateway.expects(:find_by_id).with(2).returns(crop_entity)
          @agricultural_task_gateway.expects(:find_by_id).with(3).returns(task_entity)
          @crop_task_template_gateway.expects(:find_by_agricultural_task_id_and_crop_id).returns(nil)
          @crop_task_template_gateway.expects(:create_detail).raises(record_invalid)
          @output_port.expects(:on_failure).with do |failure_dto|
            assert_equal :validation_failed, failure_dto.reason
            assert_equal [ "Name can't be blank" ], failure_dto.errors
            true
          end

          @interactor.call(input_dto)
        end
      end
    end
  end
end
