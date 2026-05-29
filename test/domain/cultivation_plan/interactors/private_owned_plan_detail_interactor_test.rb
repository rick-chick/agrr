# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PrivateOwnedPlanDetailInteractorTest < DomainLibTestCase
        FakeTranslator = Struct.new(:dummy) do
          def t(key, **options)
            I18n.t(key, **options)
          end
        end

        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @private_read_gateway = mock
          @cultivation_plan_gateway = mock
          @crop_gateway = mock
          @output_port = mock
          @user_lookup = mock
          @logger = mock
          @logger.stubs(:warn)
          @logger.stubs(:error)
          @interactor = PrivateOwnedPlanDetailInteractor.new(
            output_port: @output_port,
            user_id: @user_id,
            private_read_gateway: @private_read_gateway,
            cultivation_plan_gateway: @cultivation_plan_gateway,
            crop_gateway: @crop_gateway,
            translator: FakeTranslator.new(nil),
            logger: @logger,
            user_lookup: @user_lookup
          )
        end

        def read_snapshot(plan_id: 5)
          Dtos::PrivatePlanReadSnapshot.new(
            id: plan_id,
            display_name: "My plan",
            farm_display_name: "Farm A",
            total_area: 100.0,
            field_cultivations_count: 0,
            cultivation_plan_fields_count: 1,
            planning_start_date: Date.new(2026, 1, 1),
            planning_end_date: Date.new(2026, 12, 31),
            status: "draft",
            field_cultivations: [],
            cultivation_plan_fields: [],
            palette_used_crop_ids: []
          )
        end

        def crop_entity(id:, name:)
          Domain::Crop::Entities::CropEntity.new(
            id: id,
            user_id: @user_id,
            name: name,
            variety: "v",
            is_reference: false,
            area_per_unit: 1.0,
            revenue_per_area: 1.0,
            region: "jp",
            groups: [],
            crop_stages: [],
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
        end

        test "dispatches success with mapped private plan detail" do
          plan_id = 5
          snapshot = read_snapshot(plan_id: plan_id)
          crops = [ crop_entity(id: 10, name: "B") ]
          filter = Domain::Shared::Policies::CropPolicy.index_list_filter(@user)

          @user_lookup.expects(:find).with(@user_id).returns(@user)
          read_wire = stub
          Mappers::PrivatePlanReadSnapshotMapper.expects(:from_snapshot).with(read_wire).returns(snapshot)
          @private_read_gateway.expects(:find_plan_read_snapshot_by_plan_id).with(plan_id: plan_id).returns(read_wire)
          @cultivation_plan_gateway.expects(:find_by_id).with(plan_id).returns(
            domain_private_plan_entity(id: plan_id, user_id: @user_id)
          )
          @crop_gateway.expects(:list_index_for_filter).with(filter).returns(crops)
          @output_port.expects(:on_success).with do |detail|
            detail.is_a?(Dtos::PrivateCultivationPlanDetail) &&
              detail.id == plan_id &&
              detail.display_name == "My plan" &&
              detail.palette_crops.length == 1 &&
              detail.palette_crops.first.name == "B"
          end

          @interactor.call(plan_id: plan_id)
        end

        test "dispatches not_found when plan owned by another user" do
          plan_id = 5

          @user_lookup.expects(:find).returns(@user)
          read_wire = stub
          Mappers::PrivatePlanReadSnapshotMapper.expects(:from_snapshot).with(read_wire).returns(
            read_snapshot(plan_id: plan_id)
          )
          @private_read_gateway.expects(:find_plan_read_snapshot_by_plan_id).with(plan_id: plan_id).returns(read_wire)
          @cultivation_plan_gateway.expects(:find_by_id).returns(
            domain_private_plan_entity(id: plan_id, user_id: 99)
          )
          @crop_gateway.expects(:list_index_for_filter).never
          @output_port.expects(:on_not_found)

          @interactor.call(plan_id: plan_id)
        end

        test "dispatches not_found when read snapshot missing" do
          @user_lookup.expects(:find).returns(@user)
          @private_read_gateway.expects(:find_plan_read_snapshot_by_plan_id).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("missing")
          )
          @cultivation_plan_gateway.expects(:find_by_id).never
          @output_port.expects(:on_not_found)

          @interactor.call(plan_id: 5)
        end
      end
    end
  end
end
