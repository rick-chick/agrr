# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PublicPlanSaveInteractorTest < DomainLibTestCase
        setup do
          @logger = ::Logger.new(File::NULL)
          @translator = Object.new
          def @translator.t(key)
            key
          end

          @output_port = mock("output_port")
          @txn_gateway = mock("txn_gateway")
          @read_gateway = mock("read_gateway")
          @farm_gateway = mock("farm_gateway")
          @persistence_port = mock("persistence_port")

          @user_id = 42
          @plan_id = 99
          @header = Dtos::PublicPlanSaveHeaderSnapshot.new(
            plan_id: @plan_id,
            farm_id: 7
          )
          @session_data = Dtos::PublicPlanSaveSessionData.new(
            plan_id: @plan_id,
            farm_id: 7,
            field_data: []
          )
        end

        def build_interactor
          PublicPlanSaveInteractor.new(
            output_port: @output_port,
            txn_gateway: @txn_gateway,
            read_gateway: @read_gateway,
            farm_gateway: @farm_gateway,
            persistence_port: @persistence_port,
            logger: @logger,
            translator: @translator
          )
        end

        test "on_failure when plan_id is missing" do
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_MISSING_PLAN_ID
          end
          @read_gateway.expects(:find_header).never

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: nil, user_id: @user_id)
          )
        end

        test "on_failure when plan header is not found" do
          @read_gateway.expects(:find_header).with(plan_id: @plan_id).returns(nil)
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_PLAN_NOT_FOUND
          end

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end

        test "on_failure when reference farm is not found" do
          @read_gateway.expects(:find_header).with(plan_id: @plan_id).returns(@header)
          @farm_gateway.expects(:find_by_id).with(7).returns(nil)
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_PLAN_NOT_FOUND
          end

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end

        test "on_success when persistence succeeds" do
          @read_gateway.expects(:find_header).with(plan_id: @plan_id).returns(@header)
          @read_gateway.expects(:list_field_rows).with(plan_id: @plan_id).returns([])
          @farm_gateway.expects(:find_by_id).with(7).returns(stub(id: 7))

          success_output = Dtos::PublicPlanSaveFromSessionOutput.new(success: true)
          @txn_gateway.expects(:within_transaction).yields
          @persistence_port.expects(:execute_save!).returns(success_output)
          @output_port.expects(:on_success)

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end

        test "uses input session_data without read gateway" do
          @read_gateway.expects(:find_header).never
          success_output = Dtos::PublicPlanSaveFromSessionOutput.new(success: true)
          @txn_gateway.expects(:within_transaction).yields
          @persistence_port.expects(:execute_save!).returns(success_output)
          @output_port.expects(:on_success)

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(
              plan_id: @plan_id,
              user_id: @user_id,
              session_data: @session_data
            )
          )
        end

        test "on_failure KIND_SAVE_FAILED when persistence returns failure" do
          @read_gateway.expects(:find_header).returns(@header)
          @read_gateway.expects(:list_field_rows).returns([])
          @farm_gateway.expects(:find_by_id).returns(stub(id: 7))

          failed = Dtos::PublicPlanSaveFromSessionOutput.new(
            success: false,
            error_message: "farm limit"
          )
          @txn_gateway.expects(:within_transaction).yields
          @persistence_port.expects(:execute_save!).returns(failed)
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_SAVE_FAILED && f.message == "farm limit"
          end

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end

        test "on_failure KIND_UNEXPECTED for InvalidTaskScheduleItem" do
          @read_gateway.expects(:find_header).returns(@header)
          @read_gateway.expects(:list_field_rows).returns([])
          @farm_gateway.expects(:find_by_id).returns(stub(id: 7))
          @txn_gateway.expects(:within_transaction).raises(
            Domain::Shared::Exceptions::InvalidTaskScheduleItem, "bad item"
          )
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_UNEXPECTED
          end

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end

        test "on_failure KIND_SAVE_FAILED for RecordInvalid" do
          @read_gateway.expects(:find_header).returns(@header)
          @read_gateway.expects(:list_field_rows).returns([])
          @farm_gateway.expects(:find_by_id).returns(stub(id: 7))
          @txn_gateway.expects(:within_transaction).raises(
            Domain::Shared::Exceptions::RecordInvalid, "invalid"
          )
          @output_port.expects(:on_failure).with do |f|
            f.kind == Dtos::PublicPlanSaveFailure::KIND_SAVE_FAILED && f.message == "invalid"
          end

          build_interactor.call(
            Dtos::PublicPlanSaveInput.new(plan_id: @plan_id, user_id: @user_id)
          )
        end
      end
    end
  end
end
