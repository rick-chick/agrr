# frozen_string_literal: true

class CultivationPlanOptimizer
  def initialize(cultivation_plan)
    @cultivation_plan = cultivation_plan
    @weather_gateway = Agrr::WeatherGateway.new
    @prediction_gateway = Agrr::PredictionGateway.new
    @optimization_gateway = Agrr::OptimizationGateway.new
  end
  
  def call
    @cultivation_plan.start_optimizing!
    
    weather_data = prepare_weather_data
    
    @cultivation_plan.field_cultivations.each do |field_cultivation|
      optimize_field_cultivation(field_cultivation, weather_data)
    end
    
    Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
    true
  rescue StandardError => e
    Rails.logger.error "❌ CultivationPlan ##{@cultivation_plan.id} optimization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @cultivation_plan.fail!(e.message)
    false
  end
  
  private
  
  def prepare_weather_data
    farm = @cultivation_plan.farm
    
    # 過去90日の実績データ
    historical = @weather_gateway.fetch(
      latitude: farm.latitude,
      longitude: farm.longitude,
      days: 90
    )
    
    # 未来730日（2年分）の予測データ
    future = @prediction_gateway.predict(
      historical_data: historical,
      days: 730
    )
    
    # データをマージ
    merge_weather_data(historical, future)
  end
  
  def merge_weather_data(historical, future)
    {
      latitude: historical['latitude'],
      longitude: historical['longitude'],
      data: (historical['data'] || []) + (future['data'] || [])
    }
  end
  
  def optimize_field_cultivation(field_cultivation, weather_data)
    field_cultivation.start_optimizing!
    
    result = @optimization_gateway.optimize(
      crop_name: field_cultivation.crop.name,
      variety: field_cultivation.crop.variety || 'general',
      weather_data: weather_data,
      field_area: field_cultivation.area,
      daily_fixed_cost: field_cultivation.field.daily_fixed_cost,
      evaluation_start: Date.current,
      evaluation_end: Date.current + 2.years
    )
    
    field_cultivation.complete_with_result!(result)
  rescue StandardError => e
    Rails.logger.error "❌ FieldCultivation ##{field_cultivation.id} optimization failed: #{e.message}"
    field_cultivation.fail_with_error!(e.message)
    raise
  end
end

