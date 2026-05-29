# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PrivateOwnedPlansListInteractorTest < DomainLibTestCase
        FakeTranslator = Struct.new(:dummy) do
          def t(key, **options)
            I18n.t(key, **options)
          end
        end

        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @private_read_gateway = mock
          @output_port = mock
          @user_lookup = mock
          @logger = mock
          @logger.stubs(:warn)
          @logger.stubs(:error)
          @interactor = PrivateOwnedPlansListInteractor.new(
            output_port: @output_port,
            user_id: @user_id,
            private_read_gateway: @private_read_gateway,
            translator: FakeTranslator.new(nil),
            logger: @logger,
            user_lookup: @user_lookup
          )
        end

        def index_row(id:)
          Dtos::PrivatePlanIndexPlanRow.new(
            id: id,
            farm_display_name: "Farm",
            total_area: 10.0,
            crops_count: 1,
            fields_count: 2,
            status: "draft",
            display_name: "Plan #{id}",
            created_at: Time.utc(2026, 1, 1)
          )
        end

        test "dispatches success with private plan index rows" do
          plan_wire = Dtos::PlanIndexPlanSnapshot.new(
            id: 1,
            farm_display_name: "Farm",
            total_area: 10.0,
            status: "draft",
            display_name: "Plan 1",
            created_at: Time.utc(2026, 1, 1)
          )

          @user_lookup.expects(:find).with(@user_id).returns(@user)
          @private_read_gateway.expects(:list_private_plan_index_plan_snapshots).with(user_id: @user_id).returns([ plan_wire ])
          @private_read_gateway.expects(:count_cultivation_plan_crops_by_plan_ids).with(plan_ids: [ 1 ]).returns({ 1 => 1 })
          @private_read_gateway.expects(:count_cultivation_plan_fields_by_plan_ids).with(plan_ids: [ 1 ]).returns({ 1 => 2 })
          @output_port.expects(:on_success).with do |rows|
            rows.size == 1 && rows.first.id == 1 && rows.first.crops_count == 1 && rows.first.fields_count == 2
          end

          @interactor.call
        end

        test "dispatches failure with session_invalid when user lookup raises RecordNotFound" do
          error_dto = mock

          @user_lookup.expects(:find).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing user"))
          @private_read_gateway.expects(:list_private_plan_index_plan_snapshots).never
          Domain::Shared::Dtos::Error
            .expects(:new).with(I18n.t("plans.errors.session_invalid")).returns(error_dto)
          @output_port.expects(:on_failure).with(error_dto)

          @interactor.call
        end

        test "dispatches failure with message when gateway raises RecordInvalid" do
          error_dto = mock

          @user_lookup.expects(:find).returns(@user)
          @private_read_gateway.expects(:list_private_plan_index_plan_snapshots).raises(
            Domain::Shared::Exceptions::RecordInvalid.new("invalid row")
          )
          Domain::Shared::Dtos::Error.expects(:new).with("invalid row").returns(error_dto)
          @output_port.expects(:on_failure).with(error_dto)

          @interactor.call
        end
      end
    end
  end
end
