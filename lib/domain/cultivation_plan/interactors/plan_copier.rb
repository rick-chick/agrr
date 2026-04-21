# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 既存の私有/公開計画を新しい年度の私有計画としてコピーする（年度計画フロー用）
      class PlanCopier
        Result = Struct.new(:new_plan, :errors, keyword_init: true) do
          def success?
            errors.empty?
          end
        end

        def initialize(source_plan:, new_year:, user:, session_id: nil, gateway: Adapters::CultivationPlan::PlanCopyGateway)
          @source_plan = source_plan
          @new_year = new_year
          @user = user
          @session_id = session_id
          @gateway = gateway
        end

        def call
          ActiveRecord::Base.transaction do
            new_plan = @gateway.copy_private_plan_for_year(
              source_plan: @source_plan,
              new_year: @new_year,
              user: @user,
              session_id: @session_id
            )
            Result.new(new_plan: new_plan, errors: [])
          end
        rescue StandardError => e
          Rails.logger.error "❌ Plan copy failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          Result.new(new_plan: nil, errors: [ e.message ])
        end
      end
    end
  end
end
