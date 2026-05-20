# frozen_string_literal: true

module Adapters
  module Backdoor
    module Gateways
      class ApplicationDatabaseClearActiveRecordGateway
        include Domain::Backdoor::Gateways::ApplicationDatabaseClearGateway

        def initialize(logger:)
          @logger = logger
        end

        def clear_application_data_preserving_anonymous_users
          before_stats = snapshot_core_counts

          ActiveRecord::Base.transaction do
            Session.delete_all
            AgriculturalTask.delete_all
            Fertilize.delete_all
            Pest.delete_all
            Pesticide.delete_all
            InteractionRule.delete_all
            CultivationPlan.delete_all
            ::Crop.delete_all
            Field.delete_all
            Farm.delete_all
            User.where(is_anonymous: false).delete_all
          end

          after_stats = snapshot_core_counts
          ClearResult.success(before: before_stats, after: after_stats)
        rescue ActiveRecord::ActiveRecordError, ActiveRecord::StatementInvalid => e
          @logger.error("❌ Error clearing database: #{e.message}")
          @logger.error(e.backtrace.join("\n"))
          ClearResult.failure("Failed to clear database: #{e.message}")
        end

        private

        def snapshot_core_counts
          ApplicationDataStats.new(
            users: User.where(is_anonymous: false).count,
            farms: Farm.count,
            fields: Field.count,
            crops: ::Crop.count,
            cultivation_plans: CultivationPlan.count
          )
        end
      end
    end
  end
end
