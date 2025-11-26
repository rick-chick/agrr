# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module PublicPlans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        setup do
          # アノニマスユーザーを作成
          @anonymous_user = User.anonymous_user
          
          # 参照農場を作成
          @farm = create(:farm, :reference,
            name: '参照農場',
            latitude: 35.6762,
            longitude: 139.6503,
            region: 'jp',
            user: @anonymous_user
          )
          
          # Public CultivationPlanを作成
          @cultivation_plan = create(:cultivation_plan,
            farm: @farm,
            user: nil,
            plan_type: 'public',
            status: 'completed'
          )
        end
        
        test "find_api_cultivation_plan が正常に動作する（認証不要）" do
          # Concern のメソッドを直接テストするため、コントローラをインスタンス化
          controller = Api::V1::PublicPlans::CultivationPlansController.new
          controller.params = ActionController::Parameters.new(id: @cultivation_plan.id)
          
          plan = controller.send(:find_api_cultivation_plan)
          
          assert_not_nil plan
          assert_equal @cultivation_plan.id, plan.id
          assert_equal 'public', plan.plan_type
        end
        
        test "find_api_cultivation_plan で存在しないIDの場合はRecordNotFoundを発生させる" do
          controller = Api::V1::PublicPlans::CultivationPlansController.new
          controller.params = ActionController::Parameters.new(id: 99999)
          
          assert_raises(ActiveRecord::RecordNotFound) do
            controller.send(:find_api_cultivation_plan)
          end
        end
      end
    end
  end
end
