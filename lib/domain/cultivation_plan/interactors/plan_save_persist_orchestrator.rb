# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存の永続化オーケストレーション（セッションから農場確保まで）。
      class PlanSavePersistOrchestrator
        def initialize(ensure_user_farm_interactor:)
          @ensure_user_farm_interactor = ensure_user_farm_interactor
        end

        # @param user_id [Integer, #to_i]
        # @param session_data [Hash, Domain::CultivationPlan::Dtos::PublicPlanSaveSessionData, #farm_id]
        # @return [Domain::CultivationPlan::Dtos::PlanSaveEnsureUserFarmOutput]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def ensure_user_farm!(user_id:, session_data:)
          reference_farm_id = extract_reference_farm_id_from_session(session_data)
          input = Dtos::PlanSaveEnsureUserFarmInput.new(
            user_id: user_id,
            reference_farm_id: reference_farm_id
          )
          @ensure_user_farm_interactor.call(input)
        end

        private

        def extract_reference_farm_id_from_session(session_data)
          raw =
            case session_data
            when Hash
              session_data[:farm_id] || session_data["farm_id"]
            else
              session_data.farm_id if session_data.respond_to?(:farm_id)
            end
          return nil if raw.nil?

          s = raw.to_s
          return nil if s.strip.empty?

          Integer(s, 10)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
