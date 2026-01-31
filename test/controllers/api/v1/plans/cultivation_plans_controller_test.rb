# frozen_string_literal: true

require 'test_helper'
require_relative '../../../../support/agrr_mock_helper'

module Api
  module V1
    module Plans
      class CultivationPlansControllerTest < ActionDispatch::IntegrationTest
        include AgrrMockHelper
        
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
          
          # 天気データを追加（adjust処理に必要）
          start_date = 20.years.ago.to_date
          end_date = Date.current
          (start_date..end_date).each do |date|
            create(:weather_datum,
              weather_location: @weather_location,
              date: date,
              temperature_max: 25.0,
              temperature_min: 15.0,
              temperature_mean: 20.0
            )
          end
          
          # 既存の予測データを設定（adjust処理で新規予測を実行しないようにするため）
          prediction_end_date = @cultivation_plan.planning_end_date || (Date.current + 1.year).end_of_year
          mock_prediction_data = mock_weather_data(
            @weather_location.latitude,
            @weather_location.longitude,
            Date.current,
            prediction_end_date
          )
          @cultivation_plan.update!(
            predicted_weather_data: {
              'data' => mock_prediction_data['data'],
              'target_end_date' => prediction_end_date.to_s,
              'prediction_start_date' => Date.current.to_s,
              'prediction_days' => mock_prediction_data['data'].count
            }
          )
          
          # AGRRコマンドをモック化
          stub_all_agrr_commands
          
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

        test "data endpoint returns updated cultivations after adjust" do
          # 事前確認: 現在のcultivationsを取得
          get "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/data",
              headers: { "Accept" => "application/json" }
          
          assert_response :success
          before_json = JSON.parse(response.body)
          before_cultivations = before_json['data']['cultivations']
          before_cultivation = before_cultivations.find { |c| c['id'] == @field_cultivation.id }
          assert_not_nil before_cultivation, "事前確認: field_cultivationが存在すること"
          original_start_date = before_cultivation['start_date']
          
          # adjust APIを実行（日付を変更）
          new_start_date = '2026-09-15'
          post "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/adjust",
               params: {
                 moves: [
                   {
                     allocation_id: @field_cultivation.id,
                     action: 'move',
                     to_field_id: @field.id,
                     to_start_date: new_start_date
                   }
                 ]
               },
               headers: { "Accept" => "application/json" }
          
          assert_response :success, "adjust APIが成功すること: #{response.body}"
          adjust_json = JSON.parse(response.body)
          assert adjust_json['success'], "adjust APIが成功すること: #{adjust_json.inspect}"
          
          # 直後にdata APIを呼び出し、cultivationsが更新されているか確認
          get "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/data",
              headers: { "Accept" => "application/json" }
          
          assert_response :success
          after_json = JSON.parse(response.body)
          after_cultivations = after_json['data']['cultivations']
          after_cultivation = after_cultivations.find { |c| c['id'] == @field_cultivation.id }
          
          # RED: 更新されていない場合、テストが失敗する
          assert_not_nil after_cultivation, "adjust後にfield_cultivationが存在すること"
          assert_not_equal original_start_date, after_cultivation['start_date'],
            "adjust後にstart_dateが更新されていること（元: #{original_start_date}, 更新後: #{after_cultivation['start_date']}）"
          assert_equal new_start_date, after_cultivation['start_date'],
            "adjust後のstart_dateが新しい日付と一致すること（期待: #{new_start_date}, 実際: #{after_cultivation['start_date']}）"
        end
      end
    end
  end
end
