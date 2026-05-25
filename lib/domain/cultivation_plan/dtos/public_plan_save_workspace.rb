# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存の永続化境界用（user + session_data のみ。ステップ間マップは PlanSaveContext）。
      class PublicPlanSaveWorkspace
        attr_reader :user_id, :session_data

        def initialize(user_id:, session_data:)
          @user_id = user_id.to_i
          @session_data = session_data
          freeze
        end

        def session_hash
          session_data.to_session_hash
        end
      end
    end
  end
end
