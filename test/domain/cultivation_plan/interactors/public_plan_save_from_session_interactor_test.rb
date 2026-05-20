# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PublicPlanSaveFromSessionInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @output_port = mock
          @translator = Adapters::Translators::RailsTranslator.new
           @logger = ::Logger.new("/dev/null")
          @fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailure
        end

        test "on_success when gateway result is successful" do
          result = Object.new
          def result.success?; true; end

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
          result = Object.new
          def result.success?; false; end
          def result.error_message; "farm limit"; end

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

        test "propagates StandardError from gateway" do
          @gateway.expects(:save_from_session).raises(StandardError.new("boom"))
          @output_port.expects(:on_success).never
          @output_port.expects(:on_failure).never

          err = assert_raises(StandardError) do
            PublicPlanSaveFromSessionInteractor.new(
              output_port: @output_port,
              public_plan_save_gateway: @gateway,
              logger: @logger,
              translator: @translator
            ).call(user: :u, session_data: {})
          end
          assert_equal "boom", err.message
        end
      end
    end
  end
end
