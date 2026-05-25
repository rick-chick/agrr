# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class PublicPlansControllerTest < ActionController::TestCase
      tests Api::V1::PublicPlansController

      setup do
        @user = create(:user)
        # Bypass authentication by stubbing the before_action
        @controller.stubs(:authenticate_api_request).returns(true)
        # Set current_user directly (no Session DB write needed)
        @controller.instance_variable_set(:@current_user, @user)
      end

      test "POST /api/v1/public_plans/save_plan - 正常に計画を保存できる" do
        @request.env["HTTP_ACCEPT"] = "application/json"

        # Interactor is stubbed so plan_id doesn't need to reference real DB record
        Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.stub(:new, proc { |**kwargs|
          Object.new.tap do |o|
            o.define_singleton_method(:call) { |*_args| kwargs[:output_port].on_success }
          end
        }) do
          post :save_plan, params: { plan_id: 99999 }

          assert_response :success
          response_body = JSON.parse(response.body)
          assert response_body["success"]
          assert_not response_body.key?("error")
        end
      end
      test "POST /api/v1/public_plans/save_plan - 存在しない計画の場合404を返す" do
        @request.env["HTTP_ACCEPT"] = "application/json"

        CompositionRoot.stubs(:public_plan_save_read_gateway).returns(
          Object.new.tap { |o| o.define_singleton_method(:find_header) { |**_| nil } }
        )

        post :save_plan, params: { plan_id: 99999 }

        assert_response :not_found
        response_body = JSON.parse(response.body)
        assert_not response_body["success"]
        assert_equal "Plan not found", response_body["error"]
      end
      test "POST /api/v1/public_plans/save_plan - plan_idが欠けている場合400を返す" do
        @request.env["HTTP_ACCEPT"] = "application/json"

        fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailure
        Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.stub(:new, proc { |**kwargs|
          Object.new.tap do |o|
            o.define_singleton_method(:call) { |*_args| kwargs[:output_port].on_failure(fdto.new(kind: fdto::KIND_MISSING_PLAN_ID)) }
          end
        }) do
          post :save_plan, params: {}

          assert_response :bad_request
          response_body = JSON.parse(response.body)
          assert_not response_body["success"]
          assert_equal "plan_id is required", response_body["error"]
        end
      end

      test "POST /api/v1/public_plans/save_plan - 保存失敗の場合エラーレスポンスを返す" do
        @request.env["HTTP_ACCEPT"] = "application/json"

        fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailure
        Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.stub(:new, proc { |**kwargs|
          Object.new.tap do |o|
            o.define_singleton_method(:call) { |*_args|
              kwargs[:output_port].on_failure(
                fdto.new(kind: fdto::KIND_SAVE_FAILED, message: "作成できるFarmは4件までです")
              )
            }
          end
        }) do
          post :save_plan, params: { plan_id: 99999 }

          assert_response :unprocessable_entity
          response_body = JSON.parse(response.body)
          assert_not response_body["success"]
          assert_includes response_body["error"], "作成できるFarmは4件までです"
        end
      end
    end
  end
end
