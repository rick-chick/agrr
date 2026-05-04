# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PublicPlanSaveFromSessionInteractorTest < ActiveSupport::TestCase
        setup do
          @gateway = mock
          @output_port = mock
          @translator = Adapters::Translators::RailsTranslator.new
          @logger = Adapters::Logger::Gateways::RailsLoggerGateway.new
          @fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailureDto
        end

        test "on_success when gateway result is successful" do
          result = Adapters::CultivationPlan::Sessions::PlanSaveSession::Result.new
          result.success = true

          @gateway.expects(:save_from_session).with(user: :u, session_data: { k: 1 }).returns(result)
          @output_port.expects(:on_success).once
          @output_port.expects(:on_failure).never

          PublicPlanSaveFromSessionInteractor.new(
            output_port: @output_port,
            public_plan_save_gateway: @gateway,
            logger: @logger,
            translator: @translator
          ).call(user: :u, session_data: { k: 1 })
        end

        test "on_failure save_failed when gateway returns unsuccessful result with message" do
          result = Adapters::CultivationPlan::Sessions::PlanSaveSession::Result.new
          result.success = false
          result.error_message = "farm limit"

          @gateway.expects(:save_from_session).returns(result)
          @output_port.expects(:on_success).never
          @output_port.expects(:on_failure).with do |dto|
            assert_equal @fdto::KIND_SAVE_FAILED, dto.kind
            assert_equal "farm limit", dto.message
            true
          end

          PublicPlanSaveFromSessionInteractor.new(
            output_port: @output_port,
            public_plan_save_gateway: @gateway,
            logger: @logger,
            translator: @translator
          ).call(user: :u, session_data: {})
        end

        test "on_failure unexpected when gateway raises InvalidTaskScheduleItem domain exception" do
          err = Domain::Shared::Exceptions::InvalidTaskScheduleItem.new("bad item")
          @gateway.expects(:save_from_session).raises(err)
          @output_port.expects(:on_success).never
          @output_port.expects(:on_failure).with do |dto|
            assert_equal @fdto::KIND_UNEXPECTED, dto.kind
            assert_equal @translator.t("public_plans.save.error"), dto.message
            true
          end

          PublicPlanSaveFromSessionInteractor.new(
            output_port: @output_port,
            public_plan_save_gateway: @gateway,
            logger: @logger,
            translator: @translator
          ).call(user: :u, session_data: {})
        end

        test "on_failure unexpected when gateway raises StandardError" do
          @gateway.expects(:save_from_session).raises(StandardError.new("boom"))
          @output_port.expects(:on_success).never
          @output_port.expects(:on_failure).with do |dto|
            assert_equal @fdto::KIND_UNEXPECTED, dto.kind
            assert_equal @translator.t("public_plans.save.error"), dto.message
            true
          end

          PublicPlanSaveFromSessionInteractor.new(
            output_port: @output_port,
            public_plan_save_gateway: @gateway,
            logger: @logger,
            translator: @translator
          ).call(user: :u, session_data: {})
        end
      end
    end
  end
end
