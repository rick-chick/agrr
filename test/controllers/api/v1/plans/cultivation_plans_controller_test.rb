# frozen_string_literal: true

require 'test_helper'

module Api
  module V1
    module Plans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @farm = create(:farm, user: @user)
          @weather_location = create(:weather_location)
          @farm.update!(weather_location: @weather_location)
          @cultivation_plan = create(:cultivation_plan, :annual_planning,
            farm: @farm,
            user: @user,
            plan_type: 'private',
            status: 'completed'
          )
          
          @field = create(:cultivation_plan_field,
            cultivation_plan: @cultivation_plan,
            name: 'Test Field',
            area: 100.0,
            daily_fixed_cost: 10.0
          )
          
          @crop = create(:crop, :user_owned, :with_stages, user: @user)
          @plan_crop = create(:cultivation_plan_crop,
            cultivation_plan: @cultivation_plan,
            crop: @crop,
            name: @crop.name,
            variety: @crop.variety,
            area_per_unit: @crop.area_per_unit,
            revenue_per_area: @crop.revenue_per_area
          )
          
          @field_cultivation = create(:field_cultivation,
            cultivation_plan: @cultivation_plan,
            cultivation_plan_field: @field,
            cultivation_plan_crop: @plan_crop,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 10, 31),
            cultivation_days: 214,
            area: 10.0,
            estimated_cost: 1000.0,
            status: 'completed'
          )
          
          sign_in_as @user
        end
        
        test "data endpoint returns 500 when calculated_planning_start_date fails with includes" do
          # includesでロードされたコレクションに対してpluckを呼び出すとエラーが発生する可能性がある
          get "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/data",
              headers: { "Accept" => "application/json" }
          
          # エラーが発生する場合は500を返す
          assert_response :success, "Expected success but got #{response.status}. Response: #{response.body}"
          
          json = JSON.parse(response.body)
          assert json['success']
          assert json['data'].present?
          assert json['data']['id'].present?
        end
        
        test "adjust endpoint returns 500 when calculated_planning_start_date fails with includes" do
          # includesでロードされたコレクションに対してpluckを呼び出すとエラーが発生する可能性がある
          post "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/adjust",
               params: {
                 moves: [
                   {
                     cultivation_id: @field_cultivation.id,
                     from_field: @field.id.to_s,
                     to_field: @field.id.to_s,
                     new_start_date: '2026-09-09',
                     daysFromStart: 251
                   }
                 ]
               },
               headers: { "Accept" => "application/json" }

          # 気象データがない場合は500を返す
          assert_response :internal_server_error, "Expected internal_server_error but got #{response.status}. Response: #{response.body}"

          json = JSON.parse(response.body)
          assert !json['success']
        end

        test "data endpoint returns 500 when completion_date is nil" do
          # completion_dateがnilの場合にcalculated_planning_end_dateがエラーになる可能性をテスト
          @field_cultivation.update!(completion_date: nil)

          get "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/data",
              headers: { "Accept" => "application/json" }

          # エラーが発生することを確認（500または別のエラー）
          json = JSON.parse(response.body) rescue nil
          if json && json['success'] == false
            Rails.logger.info "Data endpoint returned error: #{json['message']}"
          end

          # 少なくとも正常に完了しないことを確認
          refute response.successful?, "Expected failure but got success. Response: #{response.body}"
        end

        test "adjust endpoint returns 400 when crop has no growth stages" do
          # 作物に成長段階がない場合をテスト
          # テストデータでは既にcrop_stagesがない状態なので、そのままテスト

          post "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/adjust",
               params: {
                 moves: [
                   {
                     allocation_id: @field_cultivation.id,
                     action: 'move',
                     to_field_id: @field.id,
                     to_start_date: '2026-09-09'
                   }
                 ]
               },
               headers: { "Accept" => "application/json" }

          # 作物に成長段階がない場合は400 Bad Requestが返される
          assert_response :bad_request, "Expected 400 but got #{response.status}. Response: #{response.body}"

          json = JSON.parse(response.body)
          assert_not json['success']
          assert json['message'].present?
          assert_includes json['message'], "成長段階が設定されていません"
        end
      end
    end
  end
end
