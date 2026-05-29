# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @plan_gateway = mock
          @read_gateway = mock
          @available_gateway = mock
          @logger = mock
          @logger.stubs(:error)
          @public_auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)
        end

        def interactor
          RetrieveCultivationPlanInteractor.new(
            output_port: @output,
            plan_gateway: @plan_gateway,
            rest_plan_read_gateway: @read_gateway,
            available_crop_rows_gateway: @available_gateway,
            logger: @logger
          )
        end

        def plan_entity(id:, user_id:, plan_type:)
          Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: id,
            farm_id: 1,
            user_id: user_id,
            total_area: 0,
            plan_type: plan_type
          )
        end

        def workbench_plan_header
          Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
            user_id: nil,
            plan_year: 2026,
            plan_name: "p",
            plan_type: "public",
            status: "draft",
            total_area: 0.0,
            planning_start_date: nil,
            planning_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0
          )
        end

        test "dispatches success with merged available crop rows" do
          plan = workbench_plan_header
          base_snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            available_crop_rows: [],
            farm_region: "jp"
          )
          crop_rows = [ { id: 1, name: "トマト" } ]

          @plan_gateway.expects(:find_by_id).with(3).returns(
            plan_entity(id: 3, user_id: nil, plan_type: "public")
          )
          rest_plan_snapshot = stub(farm_region: "jp")
          Mappers::CultivationPlanRestPlanSnapshotMapper.expects(:load_snapshot).with(
            read_gateway: @read_gateway,
            plan_id: 3
          ).returns(rest_plan_snapshot)
          @available_gateway.expects(:list_by_farm_region).with(auth: @public_auth, farm_region: "jp").returns(crop_rows)
          Mappers::CultivationPlanWorkbenchSnapshotMapper.expects(:from_snapshots).with(
            rest_plan_snapshot: rest_plan_snapshot,
            available_crop_rows: crop_rows
          ).returns(
            Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
              plan: plan,
              fields: [],
              crops: crop_rows,
              cultivations: [],
              available_crop_rows: crop_rows,
              farm_region: "jp"
            )
          )
          @output.expects(:on_success).with do |kwargs|
            s = kwargs[:snapshot]
            s.is_a?(Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot) &&
              s.plan == plan &&
              s.available_crop_rows == crop_rows &&
              s.farm_region == "jp"
          end

          interactor.call(auth: @public_auth, plan_id: 3)
        end

        test "dispatches not_found when public auth loads private plan" do
          @plan_gateway.expects(:find_by_id).with(3).returns(
            plan_entity(id: 3, user_id: 5, plan_type: "private")
          )
          Mappers::CultivationPlanRestPlanSnapshotMapper.expects(:load_snapshot).never
          @available_gateway.expects(:list_by_farm_region).never
          @output.expects(:on_not_found)

          interactor.call(auth: @public_auth, plan_id: 3)
        end

        test "dispatches not_found when private auth denies plan access" do
          private_auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @plan_gateway.expects(:find_by_id).with(3).returns(
            plan_entity(id: 3, user_id: 2, plan_type: "private")
          )
          Mappers::CultivationPlanRestPlanSnapshotMapper.expects(:load_snapshot).never
          @available_gateway.expects(:list_by_farm_region).never
          @output.expects(:on_not_found)

          interactor.call(auth: private_auth, plan_id: 3)
        end

        test "dispatches not_found when plan entity missing without loading workbench" do
          @plan_gateway.expects(:find_by_id).with(3).raises(Domain::Shared::Exceptions::RecordNotFound)
          Mappers::CultivationPlanRestPlanSnapshotMapper.expects(:load_snapshot).never
          @available_gateway.expects(:list_by_farm_region).never
          @output.expects(:on_not_found)

          interactor.call(auth: @public_auth, plan_id: 3)
        end

        test "dispatches unexpected when workbench load raises StandardError" do
          @plan_gateway.expects(:find_by_id).returns(
            plan_entity(id: 3, user_id: nil, plan_type: "public")
          )
          Mappers::CultivationPlanRestPlanSnapshotMapper.expects(:load_snapshot).raises(StandardError.new("read failed"))
          @logger.expects(:error).with(includes("read failed"))
          @output.expects(:on_unexpected).with(message: "read failed")

          interactor.call(auth: @public_auth, plan_id: 3)
        end
      end
    end
  end
end
