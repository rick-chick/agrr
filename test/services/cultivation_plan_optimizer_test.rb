require "test_helper"

class CultivationPlanOptimizeInteractorTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @farm = create(:farm, user: @user)
  end

  test "calculate_planning_period uses next year end for public plan without field_cultivations" do
    plan = create(:cultivation_plan, :public_plan, farm: @farm, user: @user)
    plan.field_cultivations.destroy_all

    optimizer = Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor.new(
      plan_id: plan.id,
      channel_class: "OptimizationChannel",
      allocation_gateway: CompositionRoot.plan_allocation_gateway,
      interaction_rule_gateway: CompositionRoot.interaction_rule_gateway,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      logger: CompositionRoot.logger,
      weather_prediction_interactor_factory: lambda { |weather_location:, farm:|
        CompositionRoot.weather_prediction_interactor(weather_location: weather_location, farm: farm)
      }
    )
    optimizer.send(:load_snapshot!)
    planning_start, planning_end = optimizer.send(:calculate_planning_period)

    assert_equal Date.current, planning_start
    assert_equal plan.prediction_target_end_date, planning_end
  end
end
