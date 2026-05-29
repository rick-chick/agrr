# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    class PublicPlansControllerTest < ActionController::TestCase
      tests Api::V1::PublicPlansController

      setup do
        @user = create(:user)
        @controller.stubs(:authenticate_api_request).returns(true)
        @controller.instance_variable_set(:@current_user, @user)
      end

      test "POST save_plan returns success JSON when interactor succeeds" do
        @request.env["HTTP_ACCEPT"] = "application/json"

        Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.stub(:new, proc { |**kwargs|
          Object.new.tap do |o|
            o.define_singleton_method(:call) { |*_args| kwargs[:output_port].on_success }
          end
        }) do
          post :save_plan, params: { plan_id: 99_999 }

          assert_response :success
          response_body = JSON.parse(response.body)
          assert response_body["success"]
          assert_not response_body.key?("error")
        end
      end
    end
  end
end
