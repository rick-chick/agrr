# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class PlanSavePersistOrchestratorTest < DomainLibTestCase
        test "ensure_user_farm delegates to interactor with farm_id from session hash" do
          expected_output = Dtos::PlanSaveEnsureUserFarmOutput.new(
            farm_id: 77,
            farm_reused: false
          )
          interactor = mock("ensure_user_farm_interactor")
          interactor.expects(:call).with do |input|
            input.user_id == 5 && input.reference_farm_id == 10
          end.returns(expected_output)

          orchestrator = PlanSavePersistOrchestrator.new(ensure_user_farm_interactor: interactor)
          out = orchestrator.ensure_user_farm!(
            user_id: 5,
            session_data: { farm_id: 10 }
          )

          assert_equal 77, out.farm_id
        end

        test "ensure_user_farm reads farm_id from PublicPlanSaveSessionData" do
          interactor = mock("ensure_user_farm_interactor")
          interactor.expects(:call).with do |input|
            input.reference_farm_id == 12
          end.returns(
            Dtos::PlanSaveEnsureUserFarmOutput.new(farm_id: 1, farm_reused: true)
          )

          session = Dtos::PublicPlanSaveSessionData.new(
            plan_id: 1,
            farm_id: 12,
            crop_ids: [],
            field_data: []
          )
          PlanSavePersistOrchestrator.new(ensure_user_farm_interactor: interactor).ensure_user_farm!(
            user_id: 3,
            session_data: session
          )
        end
      end
    end
  end
end
