# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Backdoor
    module Interactors
      class BackdoorClearDatabaseInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock("backdoor_application_database_clear_gateway")
          @presenter = mock("presenter")
          @logger = mock("logger")
          @interactor = BackdoorClearDatabaseInteractor.new(
            output_port: @presenter,
            gateway: @gateway,
            logger: @logger
          )
        end

        test "success maps stats to success dto and logs summary" do
          before_s = Gateways::ApplicationDatabaseClearGateway::ApplicationDataStats.new(
            users: 1, farms: 2, fields: 3, crops: 4, cultivation_plans: 5
          )
          after_s = Gateways::ApplicationDatabaseClearGateway::ApplicationDataStats.new(
            users: 0, farms: 0, fields: 0, crops: 0, cultivation_plans: 0
          )
          @gateway.expects(:clear_application_data_preserving_anonymous_users).returns(
            Gateways::ApplicationDatabaseClearGateway::ClearResult.success(before: before_s, after: after_s)
          )
          @logger.expects(:error).with do |msg|
            msg.include?("Database cleared successfully") &&
              msg.include?(before_s.users.to_s) &&
              msg.include?(after_s.users.to_s)
          end
          @presenter.expects(:on_success).with do |dto|
            dto.is_a?(Dtos::BackdoorClearDatabaseOutput) &&
              dto.before_stats == before_s &&
              dto.after_stats == after_s
          end

          @interactor.call
        end

        test "failure maps error message to failure dto" do
          @gateway.expects(:clear_application_data_preserving_anonymous_users).returns(
            Gateways::ApplicationDatabaseClearGateway::ClearResult.failure("Failed to clear database: boom")
          )
          @logger.expects(:error).never
          @presenter.expects(:on_failure).with do |dto|
            dto.is_a?(Dtos::BackdoorClearDatabaseFailure) &&
              dto.message == "Failed to clear database: boom"
          end

          @interactor.call
        end
      end
    end
  end
end
