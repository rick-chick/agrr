# frozen_string_literal: true

require "test_helper"
require "stringio"
require "logger"

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = PublicPlanActiveRecordGateway.new
          @farm = create(:farm, :reference)
          @crops = [create(:crop, :reference), create(:crop, :reference)]
        end

        test "should delegate to CultivationPlanCreator and return result with plan_id" do
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: 30.0,
            crops: @crops,
            user: nil,
            session_id: 'test_session_123',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          result = @gateway.create(create_dto)

          # Creator への委譲が成功し、Result が返されることを確認
          assert_not_nil result
          assert_instance_of CultivationPlanCreator::Result, result
          assert result.success?, "Creation should succeed"
          assert_not_nil result.cultivation_plan, "CultivationPlan should be created"

          # plan_id が返されることを確認
          plan_id = result.cultivation_plan.id
          assert_not_nil plan_id, "plan_id should be present"
          assert plan_id.is_a?(Integer), "plan_id should be an integer"

          # DB に CultivationPlan が作成されていることを確認
          persisted_plan = ::CultivationPlan.find_by(id: plan_id)
          assert_not_nil persisted_plan, "CultivationPlan should be persisted"
          assert_equal @farm.id, persisted_plan.farm_id
          assert_equal 'public', persisted_plan.plan_type
          assert_equal 'test_session_123', persisted_plan.session_id
        end

        test "should log plan_id when creation succeeds" do
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: 30.0,
            crops: @crops,
            user: nil,
            session_id: 'test_session_456',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          # ログ出力を検証
          log_output = capture_log_output do
            result = @gateway.create(create_dto)
            assert result.success?
          end

          # plan_id がログに出力されていることを確認
          assert_match(/Created new CultivationPlan with plan_id:/, log_output)
        end

        test "should raise StandardError when creation fails" do
          # 無効な total_area で失敗させる
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: -1.0,  # 無効な値
            crops: @crops,
            user: nil,
            session_id: 'test_session_789',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          # 例外が発生することを確認
          error = assert_raises(StandardError) do
            @gateway.create(create_dto)
          end

          assert_not_nil error.message
          assert_match(/総面積は0より大きい値である必要があります/, error.message)
        end

        test "should log error when creation fails" do
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: -1.0,
            crops: @crops,
            user: nil,
            session_id: 'test_session_error',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          # エラーログ出力を検証
          log_output = capture_log_output do
            assert_raises(StandardError) do
              @gateway.create(create_dto)
            end
          end

          # エラーログが出力されていることを確認
          assert_match(/CultivationPlan creation failed/, log_output)
        end

        test "should handle unexpected exceptions" do
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: 30.0,
            crops: @crops,
            user: nil,
            session_id: 'test_session_exception',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          # CultivationPlanCreator が例外を発生させるようにスタブ
          CultivationPlanCreator.any_instance.stubs(:call).raises(StandardError, "Unexpected error")

          error = assert_raises(StandardError) do
            @gateway.create(create_dto)
          end

          assert_equal "Unexpected error", error.message
        end

        test "should create new CultivationPlan each time" do
          create_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: @farm,
            total_area: 30.0,
            crops: @crops,
            user: nil,
            session_id: 'test_session_unique',
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          # 1回目の作成
          result1 = @gateway.create(create_dto)
          plan_id1 = result1.cultivation_plan.id

          # 2回目の作成（同じパラメータでも新しい plan が作成される）
          result2 = @gateway.create(create_dto)
          plan_id2 = result2.cultivation_plan.id

          # 毎回新しい plan_id が発行されることを確認
          assert_not_equal plan_id1, plan_id2, "Each call should create a new plan with different plan_id"
        end

        private

        def capture_log_output
          log_output = StringIO.new
          original_logger = Rails.logger
          Rails.logger = Logger.new(log_output)
          yield
          log_output.string
        ensure
          Rails.logger = original_logger
        end
      end
    end
  end
end
