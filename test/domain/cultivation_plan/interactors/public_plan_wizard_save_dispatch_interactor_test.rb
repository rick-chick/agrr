# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PublicPlanWizardSaveDispatchInteractorTest < DomainLibTestCase
        setup do
          @cultivation_gateway = mock
          @save_gateway = mock
          @output_port = mock
          @translator = Adapters::Shared::Ports::RailsTranslatorAdapter.new
           @logger = ::Logger.new(File::NULL)
        end

        test "on_plan_not_found when plan_id is not positive" do
          @output_port.expects(:on_plan_not_found).once
          @output_port.expects(:on_requires_login).never

          PublicPlanWizardSaveDispatchInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @cultivation_gateway,
            public_plan_save_gateway: @save_gateway,
            logger: @logger,
            translator: @translator
          ).call(plan_id: nil, farm_id: 1, crop_ids: [], user: :u)
        end

        test "on_plan_not_found when plan does not exist in gateway" do
          @cultivation_gateway.expects(:public_plan_wizard_plan_exists?).with(plan_id: 9).returns(false)
          @output_port.expects(:on_plan_not_found).once

          PublicPlanWizardSaveDispatchInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @cultivation_gateway,
            public_plan_save_gateway: @save_gateway,
            logger: @logger,
            translator: @translator
          ).call(plan_id: 9, farm_id: 1, crop_ids: [], user: :u)
        end

        test "on_save_payload_unavailable when gateway returns nil payload" do
          @cultivation_gateway.expects(:public_plan_wizard_plan_exists?).with(plan_id: 9).returns(true)
          @cultivation_gateway.expects(:public_plan_wizard_save_session_payload).returns(nil)
          @output_port.expects(:on_save_payload_unavailable).with(plan_id: 9).once

          PublicPlanWizardSaveDispatchInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @cultivation_gateway,
            public_plan_save_gateway: @save_gateway,
            logger: @logger,
            translator: @translator
          ).call(plan_id: 9, farm_id: 1, crop_ids: [], user: :u)
        end

        test "on_requires_login when user is nil" do
          payload = { "plan_id" => 9 }
          @cultivation_gateway.expects(:public_plan_wizard_plan_exists?).returns(true)
          @cultivation_gateway.expects(:public_plan_wizard_save_session_payload).returns(payload)
          @output_port.expects(:on_requires_login).with(session_data: payload).once

          PublicPlanWizardSaveDispatchInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @cultivation_gateway,
            public_plan_save_gateway: @save_gateway,
            logger: @logger,
            translator: @translator
          ).call(plan_id: 9, farm_id: 1, crop_ids: [], user: nil)
        end

        test "delegates to PublicPlanSaveFromSessionInteractor when user is present and not anonymous" do
          user = Object.new
          def user.anonymous?
            false
          end
          payload = { "plan_id" => 9 }
          @cultivation_gateway.expects(:public_plan_wizard_plan_exists?).returns(true)
          @cultivation_gateway.expects(:public_plan_wizard_save_session_payload).returns(payload)

          inner = mock("save_from_session")
          inner.expects(:call).with(user: user, session_data: payload)
          PublicPlanSaveFromSessionInteractor.expects(:new).returns(inner)

          PublicPlanWizardSaveDispatchInteractor.new(
            output_port: @output_port,
            cultivation_plan_gateway: @cultivation_gateway,
            public_plan_save_gateway: @save_gateway,
            logger: @logger,
            translator: @translator
          ).call(plan_id: 9, farm_id: 1, crop_ids: [], user: user)
        end
      end
    end
  end
end
