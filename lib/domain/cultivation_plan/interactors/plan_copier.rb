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

        def initialize(source_cultivation_plan_id:, new_year:, user_id:, session_id: nil, logger:,
                       gateway:)
          @source_cultivation_plan_id = source_cultivation_plan_id
          @new_year = new_year
          @user_id = user_id
          @session_id = session_id
          @gateway = gateway
          @logger = logger
        end

        def call
          @gateway.within_transaction do
            new_plan = @gateway.copy_private_plan_for_year(
              source_cultivation_plan_id: @source_cultivation_plan_id,
              new_year: @new_year,
              user_id: @user_id,
              session_id: @session_id,
              logger: @logger
            )
            Result.new(new_plan: new_plan, errors: [])
          end
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error "❌ Plan copy failed (record invalid): #{e.message}"
          Result.new(new_plan: nil, errors: [ e.message ])
        end
      end
    end
  end
end
